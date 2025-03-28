// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console} from "forge-std/Console.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test,CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public PARTICIPANT = makeAddr("participant");
    uint256 public constant STARTING_PARTICIPANT_BALANCE = 10 ether;

    event RaffleEntered(address indexed participants);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
         vm.deal(PARTICIPANT, STARTING_PARTICIPANT_BALANCE); // works
        //
        (raffle, helperConfig) = deployer.deployContract(); // ERROR HERE
        //
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

       
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsNotEnoughETH() public {
        //Arrange
        vm.prank(PARTICIPANT);
        //Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsEntrance() public {
        vm.prank(PARTICIPANT);
        vm.deal(PARTICIPANT, STARTING_PARTICIPANT_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        address participantRecorded = raffle.getParticipant(0);
        assert(participantRecorded == PARTICIPANT);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PARTICIPANT);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PARTICIPANT);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowRentrancy() public {
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); //

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
    }

    // Check UPKEEP

    function testCheckUpKeepReturnsFalseIfNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); //
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        assert(!upkeepNeeded);
    }

    // challenge
    // testCheckUpKeepReturnsFalseIfEnoughTimeHasPassed
     function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsTrueIfEnoughTimeHasPassed() public{
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);

        (bool upKeepNeeded, ) = raffle.checkUpKeep("");

        assert(upKeepNeeded);
    }
    // testCheckUpKeepReturnsTrueWhenParametersAreMet
    // function testCheckUpKeepReturnsTrueWhenParametersAreMet() public {
        // PARAMETERS
        // bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
         // bool isOpen = s_raffleState == RaffleState.OPEN;
        // bool hasBalance = address(this).balance > 0;
        // bool hasParticipants = s_participants.length > 0;
        // upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasParticipants;
        function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert
        assert(upkeepNeeded);
    }



    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
                                        
        raffle.performUpkeep("");
    }
    
    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        uint256 currentBalance =0;
        uint256 numPlayers = 0;
        Raffle.RaffleState  rState = raffle.getRaffleState();
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__upkeepNotNeeded.selector, currentBalance, numPlayers,rState)
        );
        raffle.performUpkeep("");  
    }

    modifier  raffleEntered() {
         vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public {
        vm.prank(PARTICIPANT);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpKeeep(uint256 randomRequestId) public raffleEntered skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillrandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork{
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

       

        for (uint256 i = startingIndex; i<startingIndex + additionalEntrants; i++){
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();

        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimestamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

    

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimestamp > startingTimeStamp);
    }
}
