pub mod bsdata;
pub mod mfm;

pub use bsdata::{
    clean_faction_display_name, slugify_faction_name, BsDataParser, CatalogueFaction, CatalogueUnit,
};
pub use mfm::{
    merge_mfm_into_faction, parse_mfm_faction_yaml, MfmCostOption, MfmDetachment, MfmEnhancement,
    MfmFactionFile, MfmMetaFile, MfmPricingTier, MfmUnit, MfmWargearOption,
};

use crate::domain::catalogue::{CatalogueDatabase, DataProvenance, FactionCatalogue};
use std::collections::HashMap;

/// Builds a normalized `CatalogueDatabase` from a collection of BSData `.json` documents
/// and optional `wh40k-11e-mfm` `.yaml` faction files.
/// Automatically resolves `catalogueLinks` between primary faction catalogues and `* Library.json`
/// or parent faction catalogues (such as `Imperium - Space Marines.json`).
pub fn build_catalogue_database_from_maps(
    bsdata_files: &[(String, String)],
    mfm_files: &[(String, String)],
    provenance: DataProvenance,
) -> Result<CatalogueDatabase, String> {
    // 1. Parse all BSData JSON values and index by catalogue ID and filename
    let mut parsed_jsons: Vec<(String, String, serde_json::Value)> = Vec::new();
    let mut id_to_idx: HashMap<String, usize> = HashMap::new();

    for (filename, content) in bsdata_files {
        if filename.eq_ignore_ascii_case("Warhammer 40,000.json") {
            continue;
        }
        let val: serde_json::Value = serde_json::from_str(content)
            .map_err(|e| format!("Invalid JSON in {}: {}", filename, e))?;
        let cat_id = val
            .get("catalogue")
            .and_then(|c| c.get("id"))
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let idx = parsed_jsons.len();
        if !cat_id.is_empty() {
            id_to_idx.insert(cat_id.clone(), idx);
        }
        parsed_jsons.push((filename.clone(), cat_id, val));
    }

    // 2. Parse all MFM YAML files indexed by slug
    let mut mfm_by_slug: HashMap<String, MfmFactionFile> = HashMap::new();
    for (filename, content) in mfm_files {
        if filename.eq_ignore_ascii_case("meta.yaml") {
            continue;
        }
        if let Ok(mfm_faction) = parse_mfm_faction_yaml(content) {
            if !mfm_faction.slug.is_empty() {
                mfm_by_slug.insert(mfm_faction.slug.clone(), mfm_faction);
            }
        }
    }

    // 3. Process non-library catalogues
    let mut factions: Vec<FactionCatalogue> = Vec::new();
    for (filename, _cat_id, root_val) in &parsed_jsons {
        let lower_file = filename.to_lowercase();
        if lower_file.contains("library") || lower_file.contains("unaligned forces") {
            continue;
        }

        // Gather linked library catalogues referenced in catalogueLinks
        // (excluding allied-only imports like Imperial Knights / Agents / Titans unless it is the faction's own library or Space Marines parent)
        let mut lib_refs: Vec<&serde_json::Value> = Vec::new();
        if let Some(links) = root_val
            .get("catalogue")
            .and_then(|c| c.get("catalogueLinks"))
            .and_then(|v| v.as_array())
        {
            for link in links {
                let link_name = link.get("name").and_then(|v| v.as_str()).unwrap_or("");
                let import_root = link
                    .get("importRootEntries")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);
                // Skip generic Imperium/Chaos ally imports (Agents, Knights, Titans) unless this is a direct library for this faction
                let is_ally_import = import_root
                    && (link_name.contains("Agents of the Imperium")
                        || link_name.contains("Imperial Knights")
                        || link_name.contains("Chaos Knights")
                        || link_name.contains("Chaos Daemons")
                        || link_name.contains("Titans"));
                if is_ally_import {
                    continue;
                }
                if let Some(tid) = link.get("targetId").and_then(|v| v.as_str()) {
                    if let Some(&lib_idx) = id_to_idx.get(tid) {
                        lib_refs.push(&parsed_jsons[lib_idx].2);
                    }
                }
            }
        }

        let mut faction_cat =
            BsDataParser::parse_rich_catalogue_with_libraries(root_val, &lib_refs)?;

        // Merge MFM data if available for this faction's slug (or parent Space Marines MFM for chapters without dedicated MFM file)
        if let Some(mfm) = mfm_by_slug.get(&faction_cat.slug) {
            merge_mfm_into_faction(&mut faction_cat, mfm);
        } else if filename.starts_with("Imperium - ") {
            if let Some(sm_mfm) = mfm_by_slug.get("space-marines") {
                merge_mfm_into_faction(&mut faction_cat, sm_mfm);
            }
        }

        if !faction_cat.units.is_empty() {
            factions.push(faction_cat);
        }
    }

    factions.sort_by(|a, b| a.name.cmp(&b.name));

    Ok(CatalogueDatabase {
        provenance,
        factions,
    })
}
