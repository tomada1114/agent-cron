//! The port contracts from agent-cron-test-support, run against the real adapters. Each test
//! gets its own temporary directory; nothing touches the real `~/Library`.

use agent_cron_platform::{JsonFileCounterStore, SystemClock};
use agent_cron_test_support::{clock_contract, counter_store_contract};

#[test]
fn json_file_store_meets_the_counter_store_contract() {
    let mut dirs = Vec::new(); // keeps every TempDir alive until the test ends
    counter_store_contract(|| {
        let dir = tempfile::tempdir().unwrap();
        let store = JsonFileCounterStore::new(dir.path().join("nested").join("counter.json"));
        dirs.push(dir);
        Box::new(store)
    });
}

#[test]
fn system_clock_meets_the_clock_contract() {
    clock_contract(|| Box::new(SystemClock));
}
