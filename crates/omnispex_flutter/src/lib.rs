pub mod api;
#[cfg(not(target_arch = "wasm32"))]
mod frb_generated;

use serde::Serialize;
use std::cell::RefCell;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::slice;

thread_local! {
    static LAST_RESULT_BUF: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
}

#[derive(Serialize)]
struct BridgeErrorEnvelope {
    ok: bool,
    error: String,
}

fn err_json(msg: impl Into<String>) -> String {
    serde_json::to_string(&BridgeErrorEnvelope {
        ok: false,
        error: msg.into(),
    })
    .unwrap_or_else(|_| r#"{"ok":false,"error":"serialization error"}"#.to_string())
}

/// Dispatches an RPC operation to `api::dispatch_command` and wraps the JSON result in `{"ok":true,"data":...}`.
pub fn dispatch_rpc(op: &str, payload: &str) -> String {
    let normalized_payload = if payload.trim().is_empty() {
        "{}"
    } else {
        payload
    };
    match api::dispatch_command(op, normalized_payload) {
        Ok(raw_json) => format!(r#"{{"ok":true,"data":{}}}"#, raw_json),
        Err(e) => err_json(e),
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

/// Null-terminated C-string FFI entrypoint for native Android/Desktop (`dart:ffi`), returning `{"ok":true,"data":...}`.
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
        "{}"
    } else {
        CStr::from_ptr(payload_cstr).to_str().unwrap_or("{}")
    };
    let response = dispatch_rpc(op, payload);
    CString::new(response)
        .unwrap_or_else(|_| CString::new(r#"{"ok":false,"error":"null byte in response"}"#).unwrap())
        .into_raw()
}

/// Direct raw JSON FFI entrypoint (returns raw JSON string or `{"error": ...}`).
#[no_mangle]
pub unsafe extern "C" fn omnispex_invoke_json(
    op_cstr: *const c_char,
    payload_cstr: *const c_char,
) -> *mut c_char {
    let op = if op_cstr.is_null() {
        ""
    } else {
        CStr::from_ptr(op_cstr).to_str().unwrap_or("")
    };
    let payload = if payload_cstr.is_null() {
        "{}"
    } else {
        CStr::from_ptr(payload_cstr).to_str().unwrap_or("{}")
    };
    let response = match api::dispatch_command(op, payload) {
        Ok(json) => json,
        Err(err) => serde_json::json!({ "error": err }).to_string(),
    };
    CString::new(response)
        .unwrap_or_else(|_| CString::new(r#"{"error":"null byte in response"}"#).unwrap())
        .into_raw()
}

/// Frees a C-string returned by `omnispex_call_json` or `omnispex_invoke_json`.
#[no_mangle]
pub unsafe extern "C" fn omnispex_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr));
    }
}

#[cfg(test)]
mod tests {
    use super::dispatch_rpc;

    #[test]
    fn test_bridge_archetypes_and_rpc() {
        let ping_res = dispatch_rpc("ping", "");
        assert!(ping_res.contains("\"ok\":true"));
        assert!(ping_res.contains("omnispex_rust_core_ready"));

        let arch_res = dispatch_rpc("get_default_archetypes", "{}");
        assert!(arch_res.contains("\"ok\":true"));
        assert!(arch_res.contains("MEQ"));
    }
}
