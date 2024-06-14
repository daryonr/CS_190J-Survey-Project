pragma solidity ^0.8.0;
import {console} from "forge-std/Test.sol";
contract BlockPoll {
    struct Survey 
    {
        string description; // Descriptive text for the survey
        uint[] options; // Array of numerical options for the survey

        address owner; // Address of the user who created the survey
        mapping(uint => uint) results; // Mapping from option index to count of votes
        mapping(address => bool) hasVoted; // Tracks whether an address has voted in this survey
        mapping(address => bool) dailyBonus; // Tracks if user voted previous day

        uint maxDataPoints; // Maximum number of votes (data points) accepted for the survey
        uint dataCount; // Current count of data points collected

        uint expiryBlock; // Not sure how to use this
        bool isOpen; // check if the survey is still open for responses
        bool allowPublicResults; // Allow viewing results after the survey has closed
        address[] participants; // List of participants in the survey

    }

    // Mapping of survey ID to (participant address to reward balance)
    mapping(uint => mapping(address => uint)) public rewardBalances;

    mapping(address => uint) public lastVoteTimestamp;

    // Mapping from survey ID to Survey struct, storing all surveys
    mapping(uint => Survey) public surveys;

    // Mapping from user address to a custom user name
    mapping(address => string) public userNames;

    // ID to track and assign to the next survey created
    uint public nextSurveyId;

    // Records the amount of Ether each user has staked
    mapping(address => uint) public stakes;

    // track the number of active surveys for each user
    mapping(address => uint) public activeSurveyCount;

    // Function to fetch survey details by survey ID
    function getSurveyDetails(uint surveyId) public view returns (string memory description, uint[] memory options) {
        Survey storage survey = surveys[surveyId];
        return (survey.description, survey.options);
    }

    function stakeEther() external payable 
    {
        require(msg.value > 0, "Must stake more than 0 ETH");
        stakes[msg.sender] += msg.value;
    }

    function unstakeEther(uint amount) external {
        require(stakes[msg.sender] >= amount, "Insufficient staked amount");
       
        // Require users to keep 1 ether in their account if they are participating in active surveys
        if (activeSurveyCount[msg.sender] > 0) 
        {
            require(stakes[msg.sender] - amount >= 1 ether, "Must maintain minimum stake due to active survey participation");
        }
        stakes[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }


    // Register a user with a custom name
    function register(string calldata userName) external 
    {
        require(bytes(userNames[msg.sender]).length == 0, "Username already taken");
        userNames[msg.sender] = userName;
    }

    // Create a new survey
    function createSurvey(string calldata description, uint[] calldata options, uint durationInBlocks, uint maxDataPoints, bool publicResults) external 
    {
        require(bytes(userNames[msg.sender]).length > 0, "Registration required to create surveys");
        uint surveyId = nextSurveyId++;
        Survey storage newSurvey = surveys[surveyId];
        newSurvey.description = description;
        newSurvey.options = options;
        newSurvey.expiryBlock = block.number + durationInBlocks;
        newSurvey.maxDataPoints = maxDataPoints;
        newSurvey.owner = msg.sender;
        newSurvey.isOpen = true;
        newSurvey.allowPublicResults =publicResults;
    }

    // Vote in a survey
    function vote(uint surveyId, uint optionIndex) external {
        updateSurveyStatus(surveyId);
        Survey storage survey = surveys[surveyId];

        require(survey.isOpen, "Survey is closed");
        require(!survey.hasVoted[msg.sender], "You can only vote once per survey.");
        require(stakes[msg.sender] >= 1 ether, "Insufficient stake");
        require(activeSurveyCount[msg.sender] < 50, "Active survey participation limit reached");

        uint oneDay = 86400; 
        uint currentTime = block.timestamp;
        uint lastTimeVoted = lastVoteTimestamp[msg.sender];
        uint timeSinceLastVote = currentTime - lastTimeVoted;

        // Check if the last vote was between 24 and 48 hours ago
        bool eligibleForBonus = timeSinceLastVote >= oneDay && timeSinceLastVote < 2 * oneDay;

        if (eligibleForBonus) {
            survey.dailyBonus[msg.sender] = true; // Set daily bonus eligibility
            lastVoteTimestamp[msg.sender] = currentTime;  // Update the timestamp only if eligible for daily bonus
        } else {
            survey.dailyBonus[msg.sender] = false;
        }

        survey.results[optionIndex] += 1;
        survey.dataCount += 1;
        survey.hasVoted[msg.sender] = true;
        survey.participants.push(msg.sender); // Track participants
        activeSurveyCount[msg.sender]++;

        if (survey.dataCount >= survey.maxDataPoints) {
            closeSurvey(surveyId);
        }
    }



    function updateSurveyStatus(uint surveyId) internal 
    {
        Survey storage survey = surveys[surveyId];
        if (survey.isOpen && (survey.dataCount >= survey.maxDataPoints || block.number >= survey.expiryBlock)) 
        {
            closeSurvey(surveyId);
        }
    }

    // Close a survey
    function closeSurvey(uint surveyId) public 
    {
        Survey storage survey = surveys[surveyId];
        require(msg.sender == survey.owner || survey.dataCount == survey.maxDataPoints || 
                block.number >= survey.expiryBlock, "Cannot close survey yet");
        
        if (survey.isOpen) 
        {
            survey.isOpen = false;
            for (uint i = 0; i < survey.participants.length; i++) 
            {
                address participant = survey.participants[i];
                if (activeSurveyCount[participant] > 0) 
                {
                    activeSurveyCount[participant]--;  // Decrement active survey count for each participant
                }
            }
            calculateRewards(surveyId);
        }
    }


    function viewResults(uint surveyId) public view returns (uint[] memory) {
        Survey storage survey = surveys[surveyId];

        require(survey.allowPublicResults || msg.sender == survey.owner, "Not authorized to view results");
        
        uint[] memory resultsArray = new uint[](survey.options.length);
        for (uint i = 0; i < survey.options.length; i++) 
        {
            resultsArray[i] = survey.results[i];
        }
        return resultsArray;
    }

    function viewSurveys() public view returns (uint[] memory) 
    {
        uint[] memory surveyIds = new uint[](nextSurveyId);
        for (uint i = 0; i < nextSurveyId; i++) 
        {
            surveyIds[i] = i;
        }
        return surveyIds;
    }

    function calculateRewards(uint surveyId) internal {
        Survey storage survey = surveys[surveyId];
        require(!survey.isOpen, "Survey must be closed to distribute rewards");
        // console.log("Contract balance:", address(this).balance);
        // console.log("Number of participants:", survey.participants.length);
        uint totalReward = address(this).balance;
        uint baseRewardPerParticipant;
        uint extraReward = 0;

        if (survey.participants.length > 0) 
        {
            baseRewardPerParticipant = totalReward / survey.participants.length;

            uint eligibleForExtra = 0;
            for (uint i = 0; i < survey.participants.length; i++) 
            {
                if (survey.dailyBonus[survey.participants[i]]) 
                {
                    eligibleForExtra++;
                }
            }

            if (eligibleForExtra != 0) 
            {
                extraReward = (baseRewardPerParticipant * 10 / 100) * survey.participants.length / eligibleForExtra;
            }

            for (uint i = 0; i < survey.participants.length; i++) 
            {
                address participant = survey.participants[i];
                uint participantReward = baseRewardPerParticipant;

                if (survey.dailyBonus[survey.participants[i]]) 
                {
                    participantReward += extraReward;
                }

                rewardBalances[surveyId][participant] += participantReward;
            }
        }
    }


    // Function for participants to withdraw their rewards
    function withdrawReward(uint surveyId) public 
    {
        uint reward = rewardBalances[surveyId][msg.sender];
        require(reward > 0, "No reward available or already claimed.");

        // Clear balances to prevent reentry attack
        rewardBalances[surveyId][msg.sender] = 0;
        
        payable(msg.sender).transfer(reward);
    }
    function isSurveyOpen(uint surveyId) public view returns (bool) {
        return surveys[surveyId].isOpen;
    }
    receive() external payable {}
}