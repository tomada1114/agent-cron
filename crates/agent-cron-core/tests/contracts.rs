//! The port contracts from agent-cron-test-support, run against its fakes. The same functions
//! run against the real adapters in agent-cron-platform's tests.

use agent_cron_test_support::{
    FixedClock, InMemoryCounterStore, clock_contract, counter_store_contract,
};

#[test]
fn in_memory_store_meets_the_counter_store_contract() {
    counter_store_contract(|| Box::new(InMemoryCounterStore::default()));
}

#[test]
fn fixed_clock_meets_the_clock_contract() {
    clock_contract(|| Box::new(FixedClock::default()));
}
