[PREVIOUS TEST CONTENT]

Clarinet.test({
  name: "Ensure table status is updated correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('restaurant_manager', 'update-table-status', [
        types.uint(1), // table number
        types.bool(true) // is cleaned
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
  }
});
