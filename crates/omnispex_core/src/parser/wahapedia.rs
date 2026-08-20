use crate::domain::dice::ValueExpr;
use crate::domain::unit::{ModelProfile, UnitProfile};
use crate::domain::weapon::{Keyword, WeaponAbility, WeaponProfile};
use regex::Regex;
use std::fmt;
use std::str::FromStr;

#[derive(Debug, PartialEq, Eq)]
pub struct ParseError(pub String);

impl fmt::Display for ParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Wahapedia parse error: {}", self.0)
    }
}

impl std::error::Error for ParseError {}

pub fn parse_weapon_ability(s: &str) -> Option<WeaponAbility> {
    let clean = s.trim().trim_matches(|c| c == '[' || c == ']' || c == '(' || c == ')');
    let upper = clean.to_uppercase();

    if upper == "TORRENT" {
        return Some(WeaponAbility::Torrent);
    }
    if upper == "LETHAL HITS" {
        return Some(WeaponAbility::LethalHits);
    }
    if upper == "DEVASTATING WOUNDS" {
        return Some(WeaponAbility::DevastatingWounds);
    }
    if upper == "TWIN-LINKED" || upper == "TWIN LINKED" {
        return Some(WeaponAbility::TwinLinked);
    }
    if upper == "BLAST" {
        return Some(WeaponAbility::Blast);
    }
    if upper == "IGNORES COVER" {
        return Some(WeaponAbility::IgnoresCover);
    }
    if upper == "HEAVY" {
        return Some(WeaponAbility::Heavy);
    }
    if upper == "LANCE" {
        return Some(WeaponAbility::Lance);
    }
    if upper == "INDIRECT FIRE" {
        return Some(WeaponAbility::IndirectFire);
    }
    if upper == "PRECISION" {
        return Some(WeaponAbility::Precision);
    }
    if upper == "HAZARDOUS" {
        return Some(WeaponAbility::Hazardous);
    }
    if upper == "ASSAULT" {
        return Some(WeaponAbility::Assault);
    }
    if upper == "EXTRA ATTACKS" {
        return Some(WeaponAbility::ExtraAttacks);
    }

    if let Some(rest) = upper.strip_prefix("SUSTAINED HITS") {
        let val_str = rest.trim();
        if let Ok(val) = val_str.parse::<u32>() {
            return Some(WeaponAbility::SustainedHits(val));
        }
    }

    if let Some(rest) = upper.strip_prefix("RAPID FIRE") {
        let val_str = rest.trim();
        if let Ok(val) = val_str.parse::<u32>() {
            return Some(WeaponAbility::RapidFire(val));
        }
    }

    if let Some(rest) = upper.strip_prefix("MELTA") {
        let val_str = rest.trim();
        if let Ok(val) = val_str.parse::<u32>() {
            return Some(WeaponAbility::Melta(val));
        }
    }

    let anti_re = Regex::new(r"(?i)^ANTI-([A-Z0-9_]+)\s+(\d+)\+?$").unwrap();
    if let Some(caps) = anti_re.captures(&upper) {
        let target_str = caps.get(1).map_or("", |m| m.as_str());
        let threshold_str = caps.get(2).map_or("", |m| m.as_str());
        if let Ok(threshold) = threshold_str.parse::<u32>() {
            return Some(WeaponAbility::Anti {
                target: Keyword::from(target_str),
                threshold,
            });
        }
    }

    None
}

pub fn parse_weapon_line(line: &str) -> Result<WeaponProfile, ParseError> {
    let re_cols = Regex::new(
        r#"^(?P<name>[^"0-9\t\[]+?)(?:\s*\[(?P<name_kw>[^\]]+)\])?\s+(?P<range>\d+"?|MELEE|N/A|-)\s+(?P<a>\d+|D\d+(?:\+\d+)?|2D\d+(?:\+\d+)?|-)\s+(?P<skill>\d+\+|N/A|-)\s+(?P<s>\d+|-)\s+(?P<ap>-?\d+|-)\s+(?P<d>\d+|D\d+(?:\+\d+)?|2D\d+(?:\+\d+)?|-)(?:\s+(?P<end_kw>.*))?$"#,
    ).unwrap();

    let trimmed = line.trim();
    if trimmed.is_empty() {
        return Err(ParseError("Empty line".to_string()));
    }

    if let Some(caps) = re_cols.captures(trimmed) {
        let name = caps.name("name").map_or("Weapon", |m| m.as_str()).trim();
        let range_raw = caps.name("range").map_or("0", |m| m.as_str());
        let range = if range_raw.eq_ignore_ascii_case("MELEE") || range_raw == "-" || range_raw == "N/A" {
            0
        } else {
            range_raw.trim_end_matches('"').parse::<u32>().unwrap_or(0)
        };

        let a_raw = caps.name("a").map_or("1", |m| m.as_str());
        let attacks = ValueExpr::from_str(a_raw).map_err(|e| ParseError(e.0))?;

        let skill_raw = caps.name("skill").map_or("3+", |m| m.as_str());
        let (skill, is_auto_hit) = if skill_raw == "N/A" || skill_raw == "-" {
            (7, true)
        } else {
            let s_val = skill_raw.trim_end_matches('+').parse::<u32>().unwrap_or(3);
            (s_val, false)
        };

        let s_raw = caps.name("s").map_or("4", |m| m.as_str());
        let strength = s_raw.parse::<u32>().unwrap_or(4);

        let ap_raw = caps.name("ap").map_or("0", |m| m.as_str());
        let ap = ap_raw.trim_start_matches('-').parse::<u32>().unwrap_or(0);

        let d_raw = caps.name("d").map_or("1", |m| m.as_str());
        let damage = ValueExpr::from_str(d_raw).map_err(|e| ParseError(e.0))?;

        let mut abilities = Vec::new();
        if is_auto_hit {
            abilities.push(WeaponAbility::Torrent);
        }

        let mut raw_keywords = Vec::new();
        if let Some(kws) = caps.name("name_kw") {
            raw_keywords.extend(kws.as_str().split(','));
        }
        if let Some(kws) = caps.name("end_kw") {
            raw_keywords.extend(kws.as_str().split(','));
        }

        for kw in raw_keywords {
            if let Some(ability) = parse_weapon_ability(kw) {
                if !abilities.contains(&ability) {
                    abilities.push(ability);
                }
            }
        }

        return Ok(WeaponProfile::new(
            name, range, attacks, skill, strength, ap, damage, abilities,
        ));
    }

    Err(ParseError(format!("Could not parse weapon line: {}", line)))
}

pub fn parse_wahapedia_weapons(text: &str) -> Vec<WeaponProfile> {
    let mut weapons = Vec::new();
    for line in text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty()
            || trimmed.starts_with("RANGED WEAPONS")
            || trimmed.starts_with("MELEE WEAPONS")
            || trimmed.starts_with("RANGE")
            || trimmed.starts_with("WEAPON")
        {
            continue;
        }

        if let Ok(w) = parse_weapon_line(trimmed) {
            weapons.push(w);
        }
    }
    weapons
}

pub fn parse_wahapedia_unit(text: &str) -> Result<UnitProfile, ParseError> {
    let mut name = "Unit".to_string();
    let mut toughness = 4u32;
    let mut save = 3u32;
    let mut wounds = 2u32;
    let mut model_count = 1usize;
    let mut invuln: Option<u32> = None;
    let mut fnp: Option<u32> = None;
    let mut keywords = Vec::new();

    let re_statline = Regex::new(
        r#"(?i)(?:M\s*(?:\d+"?|-)\s+)?T\s*(?P<t>\d+)\s+SV\s*(?P<sv>\d+)\+\s+W\s*(?P<w>\d+)"#,
    ).unwrap();

    let re_table_row = Regex::new(
        r#"^(?:\d+"?)\s+(?P<t>\d+)\s+(?P<sv>\d+)\+\s+(?P<w>\d+)"#,
    ).unwrap();

    let re_invuln = Regex::new(r#"(?i)INVULNERABLE\s+SAVE[:\s]+(\d+)\+"#).unwrap();
    let re_fnp = Regex::new(r#"(?i)FEEL\s+NO\s+PAIN[:\s]+(\d+)\+"#).unwrap();
    let re_kw_line = Regex::new(r#"(?i)KEYWORDS[:\s]+(.*)"#).unwrap();
    let re_count = Regex::new(r#"(?i)(?:MODELS|COUNT|SIZE)[:\s]+(\d+)"#).unwrap();

    for line in text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        if let Some(caps) = re_statline.captures(trimmed) {
            if let Some(m) = caps.name("t") {
                toughness = m.as_str().parse().unwrap_or(toughness);
            }
            if let Some(m) = caps.name("sv") {
                save = m.as_str().parse().unwrap_or(save);
            }
            if let Some(m) = caps.name("w") {
                wounds = m.as_str().parse().unwrap_or(wounds);
            }
            continue;
        }

        if let Some(caps) = re_table_row.captures(trimmed) {
            if let Some(m) = caps.name("t") {
                toughness = m.as_str().parse().unwrap_or(toughness);
            }
            if let Some(m) = caps.name("sv") {
                save = m.as_str().parse().unwrap_or(save);
            }
            if let Some(m) = caps.name("w") {
                wounds = m.as_str().parse().unwrap_or(wounds);
            }
            continue;
        }

        if let Some(caps) = re_invuln.captures(trimmed) {
            if let Ok(v) = caps[1].parse::<u32>() {
                invuln = Some(v);
            }
        }

        if let Some(caps) = re_fnp.captures(trimmed) {
            if let Ok(v) = caps[1].parse::<u32>() {
                fnp = Some(v);
            }
        }

        if let Some(caps) = re_kw_line.captures(trimmed) {
            for kw in caps[1].split(',') {
                let kw_clean = kw.trim();
                if !kw_clean.is_empty() {
                    keywords.push(Keyword::from(kw_clean));
                }
            }
        }

        if let Some(caps) = re_count.captures(trimmed) {
            if let Ok(cnt) = caps[1].parse::<usize>() {
                model_count = cnt;
            }
        }

        if !trimmed.contains(':') && !trimmed.contains("SV") && !trimmed.contains("RANGE") && name == "Unit" {
            name = trimmed.to_string();
        }
    }

    let model = ModelProfile::new(name.clone(), wounds, save, invuln, fnp).with_keywords(keywords.clone());
    Ok(UnitProfile::uniform(name, toughness, model, model_count, keywords))
}
