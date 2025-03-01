import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Cell, toNano } from '@ton/core';
import { WarsowToken } from '../wrappers/WarsowToken';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';

describe('WarsowToken', () => {
    let code: Cell;

    beforeAll(async () => {
        code = await compile('WarsowToken');
    });

    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let warsowToken: SandboxContract<WarsowToken>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        warsowToken = blockchain.openContract(WarsowToken.createFromConfig({}, code));

        deployer = await blockchain.treasury('deployer');

        const deployResult = await warsowToken.sendDeploy(deployer.getSender(), toNano('0.05'));

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: warsowToken.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and warsowToken are ready to use
    });
});
