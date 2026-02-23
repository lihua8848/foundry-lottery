// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfigByChainId();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        keyHash = networkConfig.keyHash;
        subscriptionId = networkConfig.subscriptionId;
        callbackGasLimit = networkConfig.callbackGasLimit;
    }

    function testRaffleInitializesInOpenState() public view {
        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.OPEN)
        );
    }

    /**
     * Enter Raffle Test
     */
    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: 0.0001 ether}();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getPlayers(0), PLAYER);
    }

    function testRaffleEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testDoesNotAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /**
     * checkUpkeep Tests
     */
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded2, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded2 == true);
    }

    /**
     * performUpkeep Tests
     */
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // It doesnt revert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.CALCULATING));
        assert(uint(requestId) != 0);
    }

    modifier skipForkTest() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    /**
     * fulfillRandomWords Tests
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipForkTest {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipForkTest
    {
        // Arrange
        uint256 additionalPlayers = 4;
        uint256 startingIndex = 1;
        address expectedWinner = makeAddr(
            string(abi.encodePacked(startingIndex))
        );

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalPlayers;
            i++
        ) {
            address newPlayer = makeAddr(string(abi.encodePacked(i)));
            hoax(newPlayer, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startTimestamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        console.log("Raffle balance", address(raffle).balance);

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        console.log(
            "Raffle balance after fulfillRandomWords",
            address(raffle).balance
        );
        uint256 randomWord = raffle.getRandomWord();
        console.log("randomWord", randomWord);
        // Assert
        address recentWinner = raffle.getRecentWinner();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 prize = entranceFee * (additionalPlayers + 1);

        console.log("recentWinner", recentWinner);
        assert(recentWinner == expectedWinner);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startTimestamp);
        assert(raffleState == Raffle.RaffleState.OPEN);
    }
}
