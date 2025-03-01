import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode } from '@ton/core';

export type WarsowTokenConfig = {};

export function warsowTokenConfigToCell(config: WarsowTokenConfig): Cell {
    return beginCell().endCell();
}

export class WarsowToken implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new WarsowToken(address);
    }

    static createFromConfig(config: WarsowTokenConfig, code: Cell, workchain = 0) {
        const data = warsowTokenConfigToCell(config);
        const init = { code, data };
        return new WarsowToken(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }
}
