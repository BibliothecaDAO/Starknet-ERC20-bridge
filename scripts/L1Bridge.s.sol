pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {CREATE3Factory} from "create3-factory/CREATE3Factory.sol";

import "../src/l1/bridge.sol";

string constant SALT = "LORDS";

contract GetL1BridgeAddress is Script {
    CREATE3Factory internal constant create3 = CREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);

    function run() public returns (address deployed) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = keccak256(bytes(SALT));
        deployed = create3.getDeployed(msg.sender, salt);

        vm.stopBroadcast();
    }
}

contract DeployL1Bridge is Script {
    CREATE3Factory internal constant create3 = CREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);

    function run() public returns (address deployed) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = keccak256(bytes(SALT));
        address starknet = address(0xde29d060D45901Fb19ED6C6e959EB22d8626708e); // goerli
        address l1Token = address(0x7543919933Eef56f754dAF6835fA97F6dfD785D8); // goerli
        uint256 l2Bridge = 0x59ed05a42af8cc47269faedf8f025465bdfff8742e07689d9e90f99655f83ff;

        // address starknet = 0xc662c410C0ECf747543f5bA90660f6ABeBD9C8c4; // mainnet
        // address l1Token = 0x686f2404e77ab0d9070a46cdfb0b7fecdd2318b0; // mainnet
        // address l2Bridge = 0xc0de; // mainnet

        deployed = create3.deploy(salt, abi.encodePacked(type(LordsL1Bridge).creationCode, abi.encode(starknet, l1Token, l2Bridge)));

        vm.stopBroadcast();
    }
}
