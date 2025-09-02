import type { HardhatUserConfig } from "hardhat/config";
import "dotenv/config";
import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { configVariable } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";

const config: HardhatUserConfig = {
	plugins: [hardhatToolboxMochaEthersPlugin], 
	solidity: {
		profiles: {
			default: {
				version: "0.8.28", 
			},
			production: {
				version: "0.8.28",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200
					},
				},
			},
		},
	},
	networks:
	{

		// Exemple L1 déjà présent
		sepolia: {
			type: "http",
			chainType: "l1",
			url: configVariable("SEPOLIA_RPC_URL"),
			accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
		},

		// ➜ Avalanche Fuji (C-Chain, testnet)
		fuji: {
			type: "http",
			chainType: "l1",
			url: configVariable("RPC_URL_FUJI"),
			accounts: [configVariable("PRIVATE_KEY")],
			chainId: 43113,
		},

	}
};

export default config;
