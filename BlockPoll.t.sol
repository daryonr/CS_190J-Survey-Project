// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BlockPoll} from "../src/BlockPoll.sol";

contract BlockPollTest is Test {
    BlockPoll public blockPoll;
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    function setUp() public {
        blockPoll = new BlockPoll();
    }
    
    function testRegisterUser() public {
        vm.prank(alice);
        blockPoll.register("Alice");
        
        string memory userName = blockPoll.userNames(alice);
        assertEq(userName, "Alice");
    }
    
    function testStakeEther() public {
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        blockPoll.stakeEther{value: 2 ether}();
        
        uint256 stake = blockPoll.stakes(alice);
        assertEq(stake, 2 ether);
    }
    
 
    
    function testCreateSurvey() public {
        vm.prank(alice);
        blockPoll.register("Alice");
        
        uint[] memory options = new uint[](3);
        options[0] = 1;
        options[1] = 2;
        options[2] = 3;
        
        vm.prank(alice);
        blockPoll.createSurvey("Favorite Color?", options, 100, 1000, true);
        
        (string memory description, uint[] memory retrievedOptions) = blockPoll.getSurveyDetails(0);
        
        assertEq(description, "Favorite Color?");
        assertEq(retrievedOptions.length, 3);
        assertEq(retrievedOptions[0], 1);
        assertEq(retrievedOptions[1], 2);
        assertEq(retrievedOptions[2], 3);
    }
    function testVoteInSurvey() public {
        // Setup: Alice creates a survey
        vm.prank(alice);
        blockPoll.register("Alice");
        uint[] memory options = new uint[](3);
        options[0] = 1;
        options[1] = 2;
        options[2] = 3;
        vm.prank(alice);
        blockPoll.createSurvey("Favorite Color?", options, 100, 1000, true);

        // Alice stakes enough ether to participate
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        blockPoll.stakeEther{value: 2 ether}();

        // Voting in the survey
        vm.prank(alice);
        blockPoll.vote(0, 1); // Voting for option 2
        
        // Check results
        uint[] memory results = blockPoll.viewResults(0);
        assertEq(results[1], 1, "The vote count for option 2 should be 1");
        
        // Checking that Alice cannot vote again
        vm.expectRevert("You can only vote once per survey.");
        vm.prank(alice);
        blockPoll.vote(0, 2);
    }
    function testCloseSurveyByOwner() public {
        // Setup: Bob creates a survey and stakes
        vm.prank(bob);
        blockPoll.register("Bob");
        uint[] memory options = new uint[](2);
        options[0] = 10;
        options[1] = 20;
        vm.prank(bob);
        blockPoll.createSurvey("Best Number?", options, 50, 2, false);

        vm.deal(bob, 5 ether);
        vm.prank(bob);
        blockPoll.stakeEther{value: 1 ether}();

        // Alice votes to add some data points
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        blockPoll.stakeEther{value: 1 ether}();
        vm.prank(alice);
        blockPoll.vote(0, 0);

        // Bob closes the survey
        vm.prank(bob);
        blockPoll.closeSurvey(0);
        
        // Ensure the survey is closed
        bool isOpen = blockPoll.isSurveyOpen(0);
        assertFalse(isOpen, "Survey should be closed by the owner.");
    }
    function testVotingRestrictions() public {
        // Setup: Alice registers, creates a survey, and stakes
        vm.prank(alice);
        blockPoll.register("Alice");
        uint[] memory options = new uint[](3);
        options[0] = 1;
        options[1] = 2;
        options[2] = 3;
        vm.prank(alice);
        blockPoll.createSurvey("Opinion Poll", options, 1000, 5, true);
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        blockPoll.stakeEther{value: 1 ether}();

        // Bob tries to vote without staking enough Ether
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        vm.expectRevert("Insufficient stake");
        blockPoll.vote(0, 1);

        // Alice tries to vote in too many active surveys
        for (uint i = 1; i <= 50; i++) {
            vm.prank(alice);
            uint[] memory newOptions = new uint[](1);
            newOptions[0] = i;
            blockPoll.createSurvey(string(abi.encodePacked("Survey ", i)), newOptions, 1000, 5, true);
            vm.prank(alice);
            blockPoll.vote(i, 0);
        }
        vm.expectRevert("Active survey participation limit reached");
        vm.prank(alice);
        blockPoll.vote(0, 0);
    }
    function testRegistrationConstraints() public {
        // Alice registers initially
        vm.prank(alice);
        blockPoll.register("Alice");
        string memory userName = blockPoll.userNames(alice);
        assertEq(userName, "Alice");

        // Alice tries to register again
        vm.expectRevert("Username already taken");
        vm.prank(alice);
        blockPoll.register("Alice2");
    }
    function testUnstakeEtherWithActiveSurveys() public {
        vm.prank(bob);
        blockPoll.register("Bob");
        uint[] memory options = new uint[](2);
        options[0] = 10;
        options[1] = 20;
        vm.prank(bob);
        blockPoll.createSurvey("Number Poll", options, 1000, 10, true);
        vm.deal(bob, 10 ether);
        vm.prank(bob);
        blockPoll.stakeEther{value: 5 ether}();

        vm.prank(bob);
        blockPoll.vote(0, 0);

        vm.expectRevert("Must maintain minimum stake due to active survey participation");
        vm.prank(bob);
        blockPoll.unstakeEther(4.5 ether);
    }
    
    function testUserRegistrationAndRetrieval() public {
    // Alice registers with a username
        vm.prank(alice);
        blockPoll.register("Alice123");

        // Retrieve and check Alice's username
        string memory retrievedName = blockPoll.userNames(alice);
        assertEq(retrievedName, "Alice123", "Username should match the registered name");
    }
    
    function testExpiredSurveyHandling() public {
        // Setup: Bob creates a survey that expires quickly
        vm.prank(bob);
        blockPoll.register("Bob");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        uint expiryBlock = block.number + 5;  // Expires after 5 blocks
        vm.prank(bob);
        blockPoll.createSurvey("Expire Soon", options, expiryBlock, 5, true);

        // Move time to after the expiry block
        vm.roll(expiryBlock + 1);

        // Bob tries to vote after expiry
        vm.prank(bob);
        vm.expectRevert("Survey is closed");
        blockPoll.vote(0, 1);
    }
    function testReregistrationAttempt() public {
        // Alice registers initially
        vm.prank(alice);
        blockPoll.register("AliceInitial");

        // Alice tries to register again with the same name
        vm.expectRevert("Username already taken");
        vm.prank(alice);
        blockPoll.register("AliceInitial");

        // Alice tries to register again with a different name
        vm.expectRevert("Username already taken");
        vm.prank(alice);
        blockPoll.register("AliceNew");
    }
    function testNonOwnerSurveyClosure() public {
        // Setup: Alice creates a survey
        vm.prank(alice);
        blockPoll.register("Alice");
        uint[] memory options = new uint[](2);
        options[0] = 10;
        options[1] = 20;
        vm.prank(alice);
        blockPoll.createSurvey("Exclusive Survey", options, 100, 5, true);

        // Bob tries to close Alice's survey
        vm.prank(bob);
        vm.expectRevert("Cannot close survey yet");
        blockPoll.closeSurvey(0);
    }
    function testViewSurveyResultsRestrictions() public {
        // Setup: Alice creates a survey with restricted results
        vm.prank(alice);
        blockPoll.register("Alice");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        vm.prank(alice);
        blockPoll.createSurvey("Restricted Survey", options, 1000, 5, false);

        // Bob tries to view the results before voting
        vm.prank(bob);
        vm.expectRevert("Not authorized to view results");
        blockPoll.viewResults(0);

        // Alice views the results
        vm.prank(alice);
        uint[] memory results = blockPoll.viewResults(0);
        assertEq(results.length, 2, "Should return the correct results length");
    }
    function testMultipleVotes() public {
        // Setup: Alice creates a survey and stakes
        vm.prank(alice);
        blockPoll.register("Alice");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        vm.prank(alice);
        blockPoll.createSurvey("Multiple Votes Test", options, 100, 5, true);
        vm.deal(alice, 2 ether);
        vm.prank(alice);
        blockPoll.stakeEther{value: 1 ether}();

        // First vote
        vm.prank(alice);
        blockPoll.vote(0, 0);

        // Attempt second vote
        vm.prank(alice);
        vm.expectRevert("You can only vote once per survey.");
        blockPoll.vote(0, 1);
    }
    function testSurveyCreationConstraints() public {
        // Unregistered user tries to create a survey
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        vm.expectRevert("Registration required to create surveys");
        vm.prank(bob);
        blockPoll.createSurvey("Unauthorized Survey", options, 100, 5, true);

        // Registered user creates a survey
        vm.prank(alice);
        blockPoll.register("Alice");
        vm.prank(alice);
        blockPoll.createSurvey("Authorized Survey", options, 100, 5, true);
    }
    function testVoteWithoutStake() public {
        // Setup: Bob registers and creates a survey
        vm.prank(bob);
        blockPoll.register("Bob");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        vm.prank(bob);
        blockPoll.createSurvey("No Stake Vote Test", options, 100, 5, true);

        // Attempt to vote without staking
        vm.prank(bob);
        vm.expectRevert("Insufficient stake");
        blockPoll.vote(0, 0);
    }
}
