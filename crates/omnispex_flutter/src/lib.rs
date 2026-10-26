pub mod api;
#[cfg(not(target_arch = "wasm32"))]
mod frb_generated;

use api::*;
use omnispex_core::domain::{
    AcquisitionState, ArchetypeRoster, ArmyList, CatalogueDatabase, FactionCatalogue, GameSystem,
    MatchRecord, MatchResult, UnitProfile, WeaponLoadoutEntry, WeaponProfile, WishlistItem,
    WishlistPriority, WishlistSortField,
};
use omnispex_core::engine::CombatContext;
use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::slice;

thread_local! {
    static LAST_RESULT_BUF: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
}

#[derive(Deserialize)]
struct SimulateReq {
    weapon: WeaponProfile,
    target: UnitProfile,
    context: CombatContext,
    iterations: u32,
}

#[derive(Deserialize)]
struct SimulateSquadReq {
    loadout: Vec<WeaponLoadoutEntry>,
    target: UnitProfile,
    context: CombatContext,
    iterations: u32,
}

#[derive(Deserialize)]
struct CompareReq {
    weapons: Vec<WeaponProfile>,
    target: UnitProfile,
    context: CombatContext,
    iterations: u32,
}

#[derive(Deserialize)]
struct BenchmarkReq {
    weapon: WeaponProfile,
    roster: ArchetypeRoster,
    context: CombatContext,
    iterations: u32,
}

#[derive(Deserialize)]
struct EvaluateListReq {
    list: ArmyList,
    faction: Option<FactionCatalogue>,
}

#[derive(Deserialize)]
struct UpsertWishlistReq {
    items: Vec<WishlistItem>,
    item: WishlistItem,
    active_faction_id: Option<String>,
}

#[derive(Deserialize)]
struct QueryWishlistReq {
    items: Vec<WishlistItem>,
    faction_id: Option<String>,
    #[serde(default)]
    query: String,
    priority_filter: Option<WishlistPriority>,
    state_filter: Option<AcquisitionState>,
    #[serde(default)]
    sort_by: WishlistSortField,
}

#[derive(Deserialize)]
struct EvaluateMatchesReq {
    matches: Vec<MatchRecord>,
    game_system: Option<GameSystem>,
    #[serde(default)]
    query: String,
    faction_filter: Option<String>,
    result_filter: Option<MatchResult>,
}

#[derive(Deserialize)]
struct SearchCatalogueReq {
    db: CatalogueDatabase,
    #[serde(default)]
    query: String,
    faction_filter: Option<String>,
    category_filter: Option<String>,
    #[serde(default)]
    include_legends: bool,
}

#[derive(Serialize)]
struct BridgeEnvelope<T: Serialize> {
    ok: bool,
    data: Option<T>,
    error: Option<String>,
}

fn ok_json<T: Serialize>(val: T) -> String {
    serde_json::to_string(&BridgeEnvelope {
        ok: true,
        data: Some(val),
        error: None,
    })
    .unwrap_or_else(|e| err_json(e.to_string()))
}

fn err_json(msg: impl Into<String>) -> String {
    serde_json::to_string(&BridgeEnvelope::<serde_json::Value> {
        ok: false,
        data: None,
        error: Some(msg.into()),
    })
    .unwrap_or_else(|_| r#"{"ok":false,"error":"serialization error"}"#.to_string())
}

pub fn dispatch_rpc(op: &str, payload: &str) -> String {
    match op {
        "ping" => ok_json("omnispex_rust_core_ready"),
        "get_default_archetypes" => ok_json(get_default_archetypes()),
        "simulate_matchup" => match serde_json::from_str::<SimulateReq>(payload) {
            Ok(req) => ok_json(simulate_matchup(
                req.weapon,
                req.target,
                req.context,
                req.iterations,
            )),
            Err(e) => err_json(format!("Invalid simulate_matchup payload: {}", e)),
        },
        "simulate_squad_matchup" => match serde_json::from_str::<SimulateSquadReq>(payload) {
            Ok(req) => ok_json(simulate_squad_matchup(
                req.loadout,
                req.target,
                req.context,
                req.iterations,
            )),
            Err(e) => err_json(format!("Invalid simulate_squad_matchup payload: {}", e)),
        },
        "compare_profiles" => match serde_json::from_str::<CompareReq>(payload) {
            Ok(req) => match compare_profiles_api(
                req.weapons,
                req.target,
                req.context,
                req.iterations,
            ) {
                Ok(res) => ok_json(res),
                Err(e) => err_json(e),
            },
            Err(e) => err_json(format!("Invalid compare_profiles payload: {}", e)),
        },
        "evaluate_archetypes" => match serde_json::from_str::<BenchmarkReq>(payload) {
            Ok(req) => ok_json(evaluate_archetypes_api(
                req.weapon,
                req.roster,
                req.context,
                req.iterations,
            )),
            Err(e) => err_json(format!("Invalid evaluate_archetypes payload: {}", e)),
        },
        "parse_bsdata_catalogue" => match parse_bsdata_catalogue_api(payload) {
            Ok(cat) => ok_json(cat),
            Err(e) => err_json(e),
        },
        "search_catalogue_units" => match serde_json::from_str::<SearchCatalogueReq>(payload) {
            Ok(req) => ok_json(req.db.search_units(
                &req.query,
                req.faction_filter.as_deref(),
                req.category_filter.as_deref(),
                req.include_legends,
            )),
            Err(e) => err_json(format!("Invalid search_catalogue_units payload: {}", e)),
        },
        "evaluate_army_list" => match serde_json::from_str::<EvaluateListReq>(payload) {
            Ok(req) => ok_json(evaluate_army_list_api(req.list, req.faction)),
            Err(e) => err_json(format!("Invalid evaluate_army_list payload: {}", e)),
        },
        "upsert_wishlist" => match serde_json::from_str::<UpsertWishlistReq>(payload) {
            Ok(req) => ok_json(upsert_wishlist_api(
                req.items,
                req.item,
                req.active_faction_id,
            )),
            Err(e) => err_json(format!("Invalid upsert_wishlist payload: {}", e)),
        },
        "query_wishlist" => match serde_json::from_str::<QueryWishlistReq>(payload) {
            Ok(req) => ok_json(query_wishlist_api(
                &req.items,
                req.faction_id.as_deref(),
                &req.query,
                req.priority_filter,
                req.state_filter,
                req.sort_by,
            )),
            Err(e) => err_json(format!("Invalid query_wishlist payload: {}", e)),
        },
        "evaluate_matches" => match serde_json::from_str::<EvaluateMatchesReq>(payload) {
            Ok(req) => ok_json(evaluate_matches_api(
                &req.matches,
                req.game_system,
                &req.query,
                req.faction_filter.as_deref(),
                req.result_filter,
            )),
            Err(e) => err_json(format!("Invalid evaluate_matches payload: {}", e)),
        },
        "migrate_personal_store" => match migrate_personal_store_api(payload) {
            Ok(store) => ok_json(store),
            Err(e) => err_json(e),
        },
        other => err_json(format!("Unknown RPC operation: {}", other)),
    }
}

/// Allocates a byte buffer in Rust linear memory (used by WebAssembly host and FFI callers).
#[no_mangle]
pub extern "C" fn omnispex_alloc(len: usize) -> *mut u8 {
    let mut buf = Vec::with_capacity(len);
    let ptr = buf.as_mut_ptr();
    std::mem::forget(buf);
    ptr
}

/// Frees a byte buffer previously allocated with `omnispex_alloc`.
#[no_mangle]
pub unsafe extern "C" fn omnispex_dealloc(ptr: *mut u8, len: usize) {
    if !ptr.is_null() && len > 0 {
        drop(Vec::from_raw_parts(ptr, 0, len));
    }
}

/// Invokes a Rust domain operation by UTF-8 byte slices and stores the UTF-8 response in `LAST_RESULT_BUF`.
/// Returns a pointer to the response bytes; call `omnispex_last_result_len()` to read its byte length.
#[no_mangle]
pub unsafe extern "C" fn omnispex_invoke(
    op_ptr: *const u8,
    op_len: usize,
    payload_ptr: *const u8,
    payload_len: usize,
) -> *const u8 {
    let op_slice = if op_ptr.is_null() || op_len == 0 {
        &[][..]
    } else {
        slice::from_raw_parts(op_ptr, op_len)
    };
    let payload_slice = if payload_ptr.is_null() || payload_len == 0 {
        &[][..]
    } else {
        slice::from_raw_parts(payload_ptr, payload_len)
    };

    let op_str = std::str::from_utf8(op_slice).unwrap_or("");
    let payload_str = std::str::from_utf8(payload_slice).unwrap_or("");
    let response = dispatch_rpc(op_str, payload_str);

    LAST_RESULT_BUF.with(|cell| {
        let mut buf = cell.borrow_mut();
        buf.clear();
        buf.extend_from_slice(response.as_bytes());
        buf.as_ptr()
    })
}

/// Returns the byte length of the last `omnispex_invoke` result.
#[no_mangle]
pub extern "C" fn omnispex_last_result_len() -> usize {
    LAST_RESULT_BUF.with(|cell| cell.borrow().len())
}

/// Null-terminated C-string FFI entrypoint for native Android/Desktop (`dart:ffi`).
#[no_mangle]
pub unsafe extern "C" fn omnispex_call_json(
    op_cstr: *const c_char,
    payload_cstr: *const c_char,
) -> *mut c_char {
    let op = if op_cstr.is_null() {
        ""
    } else {
        CStr::from_ptr(op_cstr).to_str().unwrap_or("")
    };
    let payload = if payload_cstr.is_null() {
        ""
    } else {
        CStr::from_ptr(payload_cstr).to_str().unwrap_or("")
    };
    let response = dispatch_rpc(op, payload);
    CString::new(response)
        .unwrap_or_else(|_| CString::new(r#"{"ok":false,"error":"null byte in response"}"#).unwrap())
        .into_raw()
}

/// Frees a C-string returned by `omnispex_call_json`.
#[no_mangle]
pub unsafe extern "C" fn omnispex_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr));
    }
}

#[cfg(test)]
mod tests {
    use super::api::*;
    use super::dispatch_rpc;
    use omnispex_core::domain::{ModelProfile, UnitProfile, ValueExpr, WeaponProfile};
    use omnispex_core::engine::CombatContext;

    #[test]
    fn test_bridge_simulate_matchup() {
        let weapon = WeaponProfile::new(
            "Bolt Rifle",
            24,
            ValueExpr::Flat(2),
            3,
            4,
            1,
            ValueExpr::Flat(1),
            vec![],
        );
        let model = ModelProfile::new("Guardsman", 1, 5, None, None);
        let target = UnitProfile::uniform("Guard Squad", 3, model, 10, vec![]);
        let context = CombatContext::default();

        let report = simulate_matchup(weapon, target, context, 500);
        assert!(report.expected_damage_dealt > 0.0);
        assert!(report.stage_probabilities.expected_attacks > 0.0);
    }

    #[test]
    fn test_bridge_archetypes_and_rpc() {
        let roster = get_default_archetypes();
        assert_eq!(roster.archetypes.len(), 5);

        let ping_res = dispatch_rpc("ping", "");
        assert!(ping_res.contains("\"ok\":true"));
        assert!(ping_res.contains("omnispex_rust_core_ready"));
    }
}
