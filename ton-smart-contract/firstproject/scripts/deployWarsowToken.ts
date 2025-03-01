import { toNano } from '@ton/core';
import { WarsowToken } from '../wrappers/WarsowToken';
import { compile, NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const warsowToken = provider.open(WarsowToken.createFromConfig({}, await compile('WarsowToken')));

    await warsowToken.sendDeploy(provider.sender(), toNano('0.05'));

    await provider.waitForDeploy(warsowToken.address);

    // run methods on `warsowToken`
}
