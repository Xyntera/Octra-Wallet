use std::ffi::{CStr, CString};
use std::os::raw::c_char;

fn into_c_string(json: String) -> *mut c_char {
    CString::new(json).unwrap().into_raw()
}

fn empty_json(message: &str) -> *mut c_char {
    into_c_string(format!(
        r#"{{"ok":false,"error":"{}"}}"#,
        json_escape(message)
    ))
}

fn read_c_string(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }
    let s = unsafe { CStr::from_ptr(ptr) }.to_string_lossy().into_owned();
    Some(s)
}

fn json_escape(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for ch in value.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            _ => out.push(ch),
        }
    }
    out
}

#[no_mangle]
pub extern "C" fn octra_core_version() -> *mut c_char {
    into_c_string(r#"{"ok":true,"version":"0.1.0","bridge":"rust-ffi"}"#.to_string())
}

#[no_mangle]
pub extern "C" fn octra_core_health() -> *mut c_char {
    into_c_string(
        r#"{"ok":true,"mode":"scaffold","server":false,"note":"Rust bridge scaffold is present but wallet-core behavior is not yet implemented"}"#
            .to_string(),
    )
}

#[no_mangle]
pub extern "C" fn octra_core_public_snapshot(address: *const c_char) -> *mut c_char {
    let Some(address) = read_c_string(address) else {
        return empty_json("missing address");
    };

    into_c_string(format!(
        r#"{{"ok":true,"address":"{}","public_balance":0,"nonce":0,"source":"rust-scaffold"}}"#,
        json_escape(&address)
    ))
}

#[no_mangle]
pub extern "C" fn octra_core_history_snapshot(
    address: *const c_char,
    limit: i32,
    offset: i32,
) -> *mut c_char {
    let Some(address) = read_c_string(address) else {
        return empty_json("missing address");
    };

    into_c_string(format!(
        r#"{{"ok":true,"address":"{}","limit":{},"offset":{},"transactions":[],"source":"rust-scaffold"}}"#,
        json_escape(&address),
        limit,
        offset
    ))
}

#[no_mangle]
pub extern "C" fn octra_core_tx_details(hash: *const c_char) -> *mut c_char {
    let Some(hash) = read_c_string(hash) else {
        return empty_json("missing hash");
    };

    into_c_string(format!(
        r#"{{"ok":true,"hash":"{}","source":"rust-scaffold"}}"#,
        json_escape(&hash)
    ))
}

#[no_mangle]
pub extern "C" fn octra_core_execute_privacy_operation(payload: *const c_char) -> *mut c_char {
    let Some(payload) = read_c_string(payload) else {
        return empty_json("missing privacy operation payload");
    };

    into_c_string(format!(
        r#"{{"ok":false,"implemented":false,"payload":"{}","error":"pvac-rs operation is not linked yet"}}"#,
        json_escape(&payload)
    ))
}

#[no_mangle]
pub extern "C" fn octra_core_recommend_fee(payload: *const c_char) -> *mut c_char {
    let Some(payload) = read_c_string(payload) else {
        return empty_json("missing fee payload");
    };

    into_c_string(format!(
        r#"{{"ok":true,"payload":"{}","fee_raw":"10000","source":"rust-scaffold"}}"#,
        json_escape(&payload)
    ))
}

#[no_mangle]
pub extern "C" fn octra_core_scan_stealth_inbox(address: *const c_char) -> *mut c_char {
    let Some(address) = read_c_string(address) else {
        return empty_json("missing address");
    };

    into_c_string(format!(
        r#"{{"ok":true,"address":"{}","claims":[],"source":"rust-scaffold"}}"#,
        json_escape(&address)
    ))
}

#[no_mangle]
pub extern "C" fn octra_core_import_token(contract_address: *const c_char) -> *mut c_char {
    let Some(contract_address) = read_c_string(contract_address) else {
        return empty_json("missing contract address");
    };

    into_c_string(format!(
        r#"{{"ok":true,"contract_address":"{}","source":"rust-scaffold"}}"#,
        json_escape(&contract_address)
    ))
}

#[no_mangle]
pub extern "C" fn octra_core_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}
