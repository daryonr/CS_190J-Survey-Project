// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BlockPoll {
    struct Survey 
    {
        string description; // Descriptive text for the survey
        uint[] options; // Array of numerical options for the survey

        address owner; // Address of the user who created the survey
        mapping(uint => uint) results; // Mapping from option index to count of votes
        mapping(address => bool) hasVoted; // Tracks whether an address has voted in this survey
        mapping(address => uint) lastVoteTimestamp; // Tracks the timestamp of the last vote for each user

        uint maxDataPoints; // Maximum number of votes (data points) accepted for the survey
        uint dataCount; // Current count of data points collected

        uint expiryBlock; // Not sure how to use this
        bool isOpen; // check if the survey is still open for responses
        bool allowPublicResults; // Allow viewing results after the survey has closed
        address[] participants; // List of participants in the survey

    }

    // Mapping of survey ID to (participant address to reward balance)
    mapping(uint => mapping(address => uint)) public rewardBalances;

    // Mapping from survey ID to Survey struct, storing all surveys
    mapping(uint => Survey) public surveys;

    // Mapping from user address to a custom user name
    mapping(address => string) public userNames;

    // ID to track and assign to the next survey created
    uint public nextSurveyId;

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
    function vote(uint surveyId, uint optionIndex) external 
    {
        Survey storage survey = surveys[surveyId];
        require(survey.dataCount < survey.maxDataPoints, "Maximum answers reached");
        require(survey.isOpen == true, "Survey is closed");
        require(survey.hasVoted[msg.sender] == false, "You can only vote once.");
        survey.results[optionIndex] += 1;
        survey.dataCount += 1;
        survey.hasVoted[msg.sender] = true;
        survey.participants.push(msg.sender); // Add participant to the list
        survey.lastVoteTimestamp[msg.sender] = block.timestamp;

        if (survey.dataCount == survey.maxDataPoints)
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
        if (survey.isOpen) {
            survey.isOpen = false;
            calculateRewards(surveyId);
        }
    }

    function viewResults(uint surveyId) public view returns (uint[] memory) 
    {
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

    function calculateRewards(uint surveyId) internal 
    {
        Survey storage survey = surveys[surveyId];
        require(!survey.isOpen, "Survey must be closed to distribute rewards");

        uint totalReward = address(this).balance;

        uint eligibleForExtra = 0;
        for (uint i = 0; i < survey.participants.length; i++) 
        {
            if (block.timestamp - survey.lastVoteTimestamp[survey.participants[i]] <= 1 days) 
            {
                eligibleForExtra++;
            }
        }

        if (eligibleForExtra != 0)
        {
            uint baseRewardPerParticipant = totalReward / survey.participants.length;
            uint extraReward = (baseRewardPerParticipant * (10 / 100)) * survey.participants.length / eligibleForExtra;
        }
        else
        {
            uint baseRewardPerParticipant = totalReward / survey.participants.length;
            uint extraReward = 0;
        }
        
        for (uint i = 0; i < survey.participants.length; i++) 
        {
            address participant = survey.participants[i];
            uint participantReward = baseRewardPerParticipant;

            if (block.timestamp - survey.lastVoteTimestamp[participant] <= 1 days) 
            {
                participantReward += extraReward;
            }

            rewardBalances[surveyId][participant] += participantReward;
        }
    }

    // Function for participants to withdraw their rewards
    function withdrawReward(uint surveyId) public 
    {
        uint reward = rewardBalances[surveyId][msg.sender];
        require(reward > 0, "No reward available or already claimed.");

        // Clear balances to prevent reentry attack
        rewardBalances[surveyId][msg.sender] = 0;
        (bool sent, ) = msg.sender.call{value: reward}("");
        require(sent, "Failed to send reward");
    }

    receive() external payable {}
}
