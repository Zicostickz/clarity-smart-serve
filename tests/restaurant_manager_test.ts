Clarinet.test({
  name: "Ensure enhanced table management functions work correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const customer = accounts.get('wallet_1')!;
    
    // Test table status update
    let block = chain.mineBlock([
      Tx.contractCall('restaurant_manager', 'update-table-status', [
        types.uint(1), // table number
        types.bool(true) // is cleaned
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Test reservation with duration
    block = chain.mineBlock([
      Tx.contractCall('restaurant_manager', 'make-reservation', [
        types.uint(1), // reservation id
        types.uint(1), // table number
        types.uint(100), // time slot
        types.uint(2), // duration
        types.uint(4) // guests
      ], customer.address)
    ]);
    
    block.receipts[0].result.expectOk();
  }
});
