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
    // Purpose: This test checks if a user can register with a username successfully.
    // Specification: Only new users should be able to register, and their username must be recorded correctly.
    // Expected Result: The test confirms that the username "Alice" is successfully associated with Alice's address after registration.
    function testRegisterUser() public {
        vm.prank(alice);
        blockPoll.register("Alice");
        
        string memory userName = blockPoll.userNames(alice);
        assertEq(userName, "Alice");
    }
    // Purpose: Validates that a user can stake ether in their account.
    // Specification: Users must be able to stake ether, and the staked amount should correctly reflect in their balance.
    // Expected Result: After Alice stakes 2 ether, her stake balance should be exactly 2 ether.
    function testStakeEther() public {
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        blockPoll.stakeEther{value: 2 ether}();
        
        uint256 stake = blockPoll.stakes(alice);
        assertEq(stake, 2 ether);
    }
    // Purpose: Ensures that a registered user can create a survey with specified parameters.
    // Specification: Surveys must be creatable with a description, options array, and other defined parameters, and must track the creator correctly.
    // Expected Results: A survey with the correct description and options is created and retrievable via the contract.
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
    // Purpose: Checks the voting functionality, ensuring users can vote correctly and only once per survey.
    // Specification: Users must be able to vote on surveys for which they have not yet voted, and subsequent votes should be blocked.
    // Expected Result: Alice's vote is recorded for the chosen option, and any attempts to vote again result in an error.
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
    // Purpose: Tests whether a survey owner can close their survey.
    // Specification: Only the survey's owner or an auto-trigger (like reaching maximum data points or expiry) should close a survey.
    // Expected Result: Bob, as the owner, closes the survey successfully, and no further votes can be cast.
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
    // Purpose: Verifies various restrictions on voting, such as staking requirements and limits on active survey participation.
    // Specification: Voters must have sufficient stake and must not exceed the limit on active survey participation.
    // Expected Results: Bob’s vote is rejected due to insufficient stakes, and Alice is blocked from voting after reaching the active survey limit.
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
    // Purpose: Ensures that users cannot register more than once.
    // Specification: A username, once registered, should not be assignable again, and users cannot change their registered name.
    // Expected Result: Any attempt by Alice to re-register or change her username should fail.
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
    // Purpose: Checks the constraints on unstaking ether based on active survey participation.
    // Specification: Users must maintain a minimum stake if they have active surveys.
    // Expected Result: Bob’s attempt to unstake more than allowed due to his active participation in surveys should fail.
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
    // Purpose: Tests the functionality of the user registration system within the smart contract, ensuring it accurately records and retrieves user information based on Ethereum addresses.
    // Specification: Upon user registration, the system should securely store the username linked to the user's Ethereum address, allowing for reliable retrieval of this information for identity verification and user interaction.
    // Expected Result:
    // Registration: When Alice registers with a username "Alice123", the system should store this information without errors.
    // Retrieval: Retrieving the username associated with Alice's address should return "Alice123". This confirms that the registration process is effective and that the data retrieval mechanisms are functioning correctly, providing accurate and expected user identification.
    function testUserRegistrationAndRetrieval() public {
    // Alice registers with a username
        vm.prank(alice);
        blockPoll.register("Alice123");

        // Retrieve and check Alice's username
        string memory retrievedName = blockPoll.userNames(alice);
        assertEq(retrievedName, "Alice123", "Username should match the registered name");
    }
    // Purpose: Validates that a survey can no longer accept votes after its expiry.
    // Specification: Surveys should automatically close upon reaching their expiry block.
    // Expected Result: Any attempts to vote in an expired survey should be rejected.
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
    // Purpose: To ensure that once registered, a user cannot register again, either with the same or a different username.
    // Specification: The contract should enforce unique registration per address to prevent multiple usernames being linked to the same account.
    // Expected Result: Alice's attempts to register again, whether with the original or a new username, should fail, confirming username uniqueness enforcement.
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
    // Purpose: Tests that only the survey owner has the authority to close their own survey prematurely.
    // Specification: Prevent unauthorized users (non-owners) from closing surveys that they do not own.
    // Expected Result: Bob's attempt to close a survey created by Alice should be rejected, maintaining proper control over survey management.
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
    // Purpose: Validates that survey results are only accessible according to the privacy settings specified upon survey creation.
    // Specification: Surveys marked as private should not allow unauthorized users to view the results.
    // Expected Result: Bob's attempt to view results of a survey he did not create should be blocked, while Alice, as the owner, can view the results freely.
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
    // Purpose: Ensures that each voter can only cast one vote per survey, to maintain vote integrity.
    // Specification: The system should prevent users from voting more than once in the same survey.
    // Expected Result: Alice's second attempt to vote in the same survey should fail, confirming that the system correctly tracks and enforces one vote per user per survey.
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
    // Purpose: This test ensures that only registered users can create surveys, upholding the requirement that participants must be authenticated to manage survey content.
    // Specification: The system should restrict the ability to create surveys to users who have completed the registration process, ensuring accountability and traceability of survey creators.
    // Expected Result:
    // Unregistered User (Bob): Attempts by Bob to create a survey without prior registration should result in a rejection, specifically an error message stating "Registration required to create surveys". This confirms the system's adherence to access control policies.
    // Registered User (Alice): Once Alice has registered, she should be able to successfully create a survey. The test verifies that the survey creation process respects user authentication and allows those who are registered to engage fully in survey activities.
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
    // Purpose: Verifies that a minimum stake is required to vote, ensuring that participants have a vested interest.
    // Specification: Voting should be contingent upon having a sufficient stake, as defined by the contract.
    // Expected Result: Bob's attempt to vote without enough stake should be rejected, enforcing the staking requirements.
    function testVoteWithoutStake() public {
        // Setup: Bob registers and creates a survey
        vm.prank(bob);
        blockPoll.register("Bob");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        vm.prank(bob);
        blockPoll.createSurvey("No Stake Vote Test", options, 100, 5, true);

        vm.prank(bob);
        vm.expectRevert("Insufficient stake");
        blockPoll.vote(0, 0);
    }
    // Purpose: Tests the enforcement of access restrictions to survey results based on privacy settings.
    // Specification: Only authorized participants should access the results of private surveys.
    // Expected Result: Bob's attempt to view results of Alice's private survey should be blocked, confirming the privacy settings are respected.
    function testSurveyAccessRestrictions() public {
        vm.prank(alice);
        blockPoll.register("Alice");
        uint[] memory options = new uint[](2);
        options[0] = 7;
        options[1] = 14;
        vm.prank(alice);
        blockPoll.createSurvey("Private Survey", options, 100, 5, false);
        vm.prank(bob);
        vm.expectRevert("Not authorized to view results");
        blockPoll.viewResults(0);
    }
    // Purpose: Confirms that users can participate in multiple surveys simultaneously without issue.
    // Specification: Participants should be able to vote in various surveys, and their participation should be correctly recorded in each.
    // Expected Result: Alice's votes in two different surveys should be correctly counted and verified, showcasing the system's capability to handle multiple participations.
    function testMultipleSurveyParticipation() public {
        vm.prank(alice);
        blockPoll.register("Alice");
        uint[] memory options1 = new uint[](2);
        options1[0] = 1;
        options1[1] = 2;
        uint[] memory options2 = new uint[](2);
        options2[0] = 3;
        options2[1] = 4;
        
        vm.prank(alice);
        blockPoll.createSurvey("Survey 1", options1, 100, 5, true);
        vm.prank(alice);
        blockPoll.createSurvey("Survey 2", options2, 100, 5, true);
        
        vm.deal(alice, 2 ether);
        vm.prank(alice);
        blockPoll.stakeEther{value: 2 ether}();
        
        vm.prank(alice);
        blockPoll.vote(0, 0);
        vm.prank(alice);
        blockPoll.vote(1, 1);
        
        uint[] memory results1 = blockPoll.viewResults(0);
        uint[] memory results2 = blockPoll.viewResults(1);
        
        assertEq(results1[0], 1, "Survey 1 Option 1 should have 1 vote");
        assertEq(results2[1], 1, "Survey 2 Option 2 should have 1 vote");
    }
    // Purpose: Ensures that survey results remain accessible after the survey is closed, if allowed by settings.
    // Specification: Closed surveys should still permit result viewing if configured to allow post-closure access.
    // Expected Result: Alice should be able to view the results of her closed survey, confirming that result access is maintained post-closure according to settings.
    function testSurveyResultsAccessAfterClosing() public {
        vm.prank(alice);
        blockPoll.register("Alice");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        vm.prank(alice);
        blockPoll.createSurvey("Closing Test Survey", options, 100, 5, true);
        
        vm.deal(alice, 2 ether);
        vm.prank(alice);
        blockPoll.stakeEther{value: 1 ether}();
        
        vm.prank(alice);
        blockPoll.vote(0, 0);
        
        vm.prank(alice);
        blockPoll.closeSurvey(0);
        
        uint[] memory results = blockPoll.viewResults(0);
        assertEq(results[0], 1, "Option 1 should have 1 vote after closing");
    }
    // Purpose: Checks that the contract handles attempts to withdraw non-existent rewards correctly.
    // Specification: Users should not be able to withdraw rewards unless they have available, unclaimed rewards.
    // Expected Result: Bob's attempt to withdraw rewards when none are available or already claimed should be denied, ensuring reward distribution integrity.
    function testWithdrawWithoutReward() public {
        vm.prank(bob);
        blockPoll.register("Bob");
        
        vm.expectRevert("No reward available or already claimed.");
        vm.prank(bob);
        blockPoll.withdrawReward(0);
    }
    // Purpose: Verifies that closed surveys do not accept additional votes.
    // Specification: Once a survey is closed, it should reject any further voting attempts.
    // Expected Result: Alice's attempt to vote in a survey after it has been closed should be prevented, maintaining the finality of the closed survey's results.
    function testVotingAfterSurveyClosure() public {
        vm.prank(alice);
        blockPoll.register("Alice");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        vm.prank(alice);
        blockPoll.createSurvey("Vote After Close", options, 100, 5, true);
        
        vm.deal(alice, 2 ether);
        vm.prank(alice);
        blockPoll.stakeEther{value: 1 ether}();
        
        vm.prank(alice);
        blockPoll.vote(0, 0);
        
        vm.prank(alice);
        blockPoll.closeSurvey(0);
        
        vm.expectRevert("Survey is closed");
        vm.prank(alice);
        blockPoll.vote(0, 1);
    }
    // Purpose: Tests the contract's handling of survey expiration based on block numbers.
    // Specification: Surveys should automatically close after a defined number of blocks, preventing any further votes.
    // Expected Result: Voting attempts past the survey's expiration should be rejected, demonstrating the contract's ability to enforce time-based survey closures.
    function testSurveyExpiryLogic() public {
        vm.prank(bob);
        blockPoll.register("Bob");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        uint durationInBlocks = 10;
        vm.prank(bob);
        blockPoll.createSurvey("Expiring Survey", options, durationInBlocks, 5, true);
        
        vm.deal(bob, 2 ether);
        vm.prank(bob);
        blockPoll.stakeEther{value: 1 ether}();
        
        vm.roll(block.number + durationInBlocks + 1);
        
        vm.prank(bob);
        vm.expectRevert("Survey is closed");
        blockPoll.vote(0, 0);
    }
    // Purpose: Ensures that stake requirements are managed correctly across multiple surveys.
    // Specification: Participants should maintain a minimum stake if they are active in any ongoing surveys.
    // Expected Result: Alice's attempt to unstake an amount that would drop her below the required minimum due to active surveys should be blocked.
    function testStakeManagementAcrossMultipleSurveys() public {
        vm.prank(alice);
        blockPoll.register("Alice");
        uint[] memory options = new uint[](2);
        options[0] = 1;
        options[1] = 2;
        
        vm.prank(alice);
        blockPoll.createSurvey("Survey 1", options, 100, 5, true);
        vm.prank(alice);
        blockPoll.createSurvey("Survey 2", options, 100, 5, true);
        
        vm.deal(alice, 2 ether);
        vm.prank(alice);
        blockPoll.stakeEther{value: 2 ether}();
        
        vm.prank(alice);
        blockPoll.vote(0, 0);
        vm.prank(alice);
        blockPoll.vote(1, 1);
        
        // Alice should not be able to unstake more than 1 ether since she's participating in surveys
        vm.expectRevert("Must maintain minimum stake due to active survey participation");
        vm.prank(alice);
        blockPoll.unstakeEther(1.5 ether);
    }
}
