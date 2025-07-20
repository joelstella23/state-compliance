import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "State Compliance Core: Register Compliance Type",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall('state-compliance-core', 'register-compliance-type', [
                types.ascii('carbon-reduction'),
                types.uint(1000),
                types.ascii('metric-tons')
            ], deployer.address)
        ]);

        // Assert transaction success
        block.receipts[0].result.expectOk();

        // Verify type registration
        const typeInfo = chain.callReadOnlyFn('state-compliance-core', 'get-compliance-type-info', 
            [types.ascii('carbon-reduction')], deployer.address);
        
        typeInfo.result.expectSome();
    }
});

Clarinet.test({
    name: "State Compliance Core: Register Compliance Entity",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall('state-compliance-core', 'register-compliance-entity', [
                types.utf8('California Environmental Agency'),
                types.utf8('State-level environmental protection agency'),
                types.utf8('California, USA')
            ], deployer.address)
        ]);

        // Assert transaction success
        block.receipts[0].result.expectOk().expectUint(1);
    }
});

Clarinet.test({
    name: "State Compliance Core: Submit Compliance Claim",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // First register a compliance type
        chain.mineBlock([
            Tx.contractCall('state-compliance-core', 'register-compliance-type', [
                types.ascii('renewable-energy'),
                types.uint(500),
                types.ascii('megawatt-hours')
            ], deployer.address)
        ]);

        // Register a compliance entity
        const registerBlock = chain.mineBlock([
            Tx.contractCall('state-compliance-core', 'register-compliance-entity', [
                types.utf8('California Energy Commission'),
                types.utf8('State energy regulatory body'),
                types.utf8('California, USA')
            ], deployer.address)
        ]);

        const entityId = registerBlock.receipts[0].result.expectOk().expectUint(1);

        // Submit a compliance claim
        const block = chain.mineBlock([
            Tx.contractCall('state-compliance-core', 'submit-compliance-claim', [
                types.uint(1),
                types.ascii('renewable-energy'),
                types.uint(100),
                types.utf8('https://example.com/evidence'),
                types.uint(1000),
                types.uint(2)
            ], deployer.address)
        ]);

        // Assert transaction success
        block.receipts[0].result.expectOk().expectUint(1);
    }
});