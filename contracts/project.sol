
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title GardenPlot
 * @dev A contract for tokenized community garden plots
 */
contract GardenPlot is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    // Plot information
    struct Plot {
        uint256 plotId;
        uint256 price; // Price in wei for renting
        uint256 size; // Size in square meters
        uint256 rentalEndTime; // Unix timestamp of rental end time
        bool isAvailable;
        address renter;
        string location; // Location description within the garden
    }
    
    // Activity information
    struct Activity {
        uint256 activityId;
        string name;
        uint256 scheduledTime; // Unix timestamp
        string description;
        address organizer;
        uint256[] participatingPlots; // Plot IDs participating in this activity
    }
    
    // Mapping from token ID to Plot
    mapping(uint256 => Plot) public plots;
    
    // Activity tracking
    Counters.Counter private _activityIds;
    mapping(uint256 => Activity) public activities;
    
    // Events
    event PlotCreated(uint256 indexed plotId, uint256 price, uint256 size, string location);
    event PlotRented(uint256 indexed plotId, address indexed renter, uint256 rentalEndTime);
    event PlotRentalEnded(uint256 indexed plotId);
    event ActivityCreated(uint256 indexed activityId, string name, uint256 scheduledTime);
    event ActivityJoined(uint256 indexed activityId, uint256 indexed plotId);
    
    constructor() ERC721("Community Garden Plot", "PLOT") Ownable(msg.sender) {}
    
    /**
     * @dev Create a new garden plot
     */
    function createPlot(uint256 price, uint256 size, string memory location, string memory tokenURI) 
        public 
        onlyOwner 
        returns (uint256) 
    {
        _tokenIds.increment();
        uint256 newPlotId = _tokenIds.current();
        
        // Mint the token
        _mint(address(this), newPlotId);
        _setTokenURI(newPlotId, tokenURI);
        
        // Create the plot data
        plots[newPlotId] = Plot({
            plotId: newPlotId,
            price: price,
            size: size,
            rentalEndTime: 0,
            isAvailable: true,
            renter: address(0),
            location: location
        });
        
        emit PlotCreated(newPlotId, price, size, location);
        
        return newPlotId;
    }
    
    /**
     * @dev Rent a garden plot
     */
    function rentPlot(uint256 plotId, uint256 durationInDays) public payable {
        Plot storage plot = plots[plotId];
        
        require(plot.isAvailable, "Plot is not available");
        require(msg.value >= plot.price * durationInDays, "Insufficient payment");
        
        plot.renter = msg.sender;
        plot.isAvailable = false;
        plot.rentalEndTime = block.timestamp + (durationInDays * 1 days);
        
        // Transfer the token to the renter
        _transfer(address(this), msg.sender, plotId);
        
        emit PlotRented(plotId, msg.sender, plot.rentalEndTime);
    }
    
    /**
     * @dev End a plot rental, can be called by the renter or automatically when time expires
     */
    function endRental(uint256 plotId) public {
        Plot storage plot = plots[plotId];
        
        // Can be called by the renter or automatically when time expires
        require(
            msg.sender == plot.renter || 
            (block.timestamp >= plot.rentalEndTime && plot.rentalEndTime > 0), 
            "Not authorized or rental not expired"
        );
        
        // Reset plot data
        plot.isAvailable = true;
        plot.renter = address(0);
        plot.rentalEndTime = 0;
        
        // Transfer the token back to the contract
        _transfer(msg.sender, address(this), plotId);
        
        emit PlotRentalEnded(plotId);
    }
    
    /**
     * @dev Create a new garden activity
     */
    function createActivity(string memory name, uint256 scheduledTime, string memory description) 
        public 
        returns (uint256) 
    {
        // Check if the caller owns at least one plot
        bool isPlotOwner = false;
        for (uint256 i = 1; i <= _tokenIds.current(); i++) {
            if (ownerOf(i) == msg.sender) {
                isPlotOwner = true;
                break;
            }
        }
        
        require(isPlotOwner || msg.sender == owner(), "Must own a plot or be the garden owner");
        
        _activityIds.increment();
        uint256 newActivityId = _activityIds.current();
        
        uint256[] memory emptyArray = new uint256[](0);
        
        activities[newActivityId] = Activity({
            activityId: newActivityId,
            name: name,
            scheduledTime: scheduledTime,
            description: description,
            organizer: msg.sender,
            participatingPlots: emptyArray
        });
        
        emit ActivityCreated(newActivityId, name, scheduledTime);
        
        return newActivityId;
    }
    
    /**
     * @dev Join a garden activity with your plot
     */
    function joinActivity(uint256 activityId, uint256 plotId) public {
        require(ownerOf(plotId) == msg.sender, "Not the plot owner");
        
        Activity storage activity = activities[activityId];
        activity.participatingPlots.push(plotId);
        
        emit ActivityJoined(activityId, plotId);
    }
    
    /**
     * @dev Get all plots owned by an address
     */
    function getPlotsByOwner(address owner) public view returns (uint256[] memory) {
        uint256 plotCount = 0;
        
        // Count plots owned by the address
        for (uint256 i = 1; i <= _tokenIds.current(); i++) {
            if (ownerOf(i) == owner) {
                plotCount++;
            }
        }
        
        // Create and populate the array
        uint256[] memory result = new uint256[](plotCount);
        uint256 resultIndex = 0;
        
        for (uint256 i = 1; i <= _tokenIds.current(); i++) {
            if (ownerOf(i) == owner) {
                result[resultIndex] = i;
                resultIndex++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get all participants for an activity
     */
    function getActivityParticipants(uint256 activityId) public view returns (address[] memory) {
        Activity storage activity = activities[activityId];
        address[] memory participants = new address[](activity.participatingPlots.length);
        
        for (uint256 i = 0; i < activity.participatingPlots.length; i++) {
            participants[i] = ownerOf(activity.participatingPlots[i]);
        }
        
        return participants;
    }
    
    /**
     * @dev Withdraw contract funds (for the garden owner)
     */
    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
