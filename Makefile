-include .env
build:; forge build

test:; forge test


install :; forge install cyfrin/foundry-devops@0.2.2 && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 && forge install foundry-rs/forge-std@v1.8.2 && forge install transmissions11/solmate@v6


deploy-sepolia :
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url ${SEPOLIA_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --verify -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY}
	
fund-sepolia:
	forge script script/Interactions.s.sol:FundSubscription --rpc-url ${SEPOLIA_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --verify -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY}

fork-test:
	forge test --fork-url ${SEPOLIA_RPC_URL} -vvvv 