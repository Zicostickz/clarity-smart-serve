import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure can make reservation for available table",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const customer = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('restaurant_manager', 'make-reservation', [
        types.uint(1), // reservation id
        types.uint(1), // table number
        types.uint(1800), // time slot
        types.uint(4), // guests
      ], customer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Verify reservation details
    let getReservation = chain.callReadOnlyFn(
      'restaurant_manager',
      'get-reservation-details',
      [types.uint(1)],
      customer.address
    );
    
    const reservation = getReservation.result.expectSome();
    assertEquals(reservation['customer'], customer.address);
    assertEquals(reservation['table-number'], types.uint(1));
  }
});

Clarinet.test({
  name: "Ensure loyalty points are added correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const customer = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('restaurant_manager', 'add-loyalty-points', [
        types.principal(customer.address),
        types.uint(100) // spending amount
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Verify points
    let getPoints = chain.callReadOnlyFn(
      'restaurant_manager',
      'get-customer-points',
      [types.principal(customer.address)],
      deployer.address
    );
    
    assertEquals(getPoints.result['points'], types.uint(1000)); // 100 * 10 rate
  }
});

Clarinet.test({
  name: "Ensure can place and retrieve order",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const customer = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('restaurant_manager', 'place-order', [
        types.uint(1), // order id
        types.list([types.uint(1), types.uint(2)]), // items
        types.uint(50), // total amount
      ], customer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Verify order details
    let getOrder = chain.callReadOnlyFn(
      'restaurant_manager',
      'get-order-details',
      [types.uint(1)],
      customer.address
    );
    
    const order = getOrder.result.expectSome();
    assertEquals(order['customer'], customer.address);
    assertEquals(order['total-amount'], types.uint(50));
    assertEquals(order['status'], "pending");
  }
});