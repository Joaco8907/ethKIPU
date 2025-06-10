// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title : Practical work no. 2: Auction
/// @author : Gonzalez Joaquin

contract Auction {
    
    // We declare the state variables.   
    address public owner;
    address public highestBidder;
    uint public endAuction;
    uint public totalFeesCollected;
    uint public bestOffer;
    bool public finished;
    
    // These constants will be used for the requirements and to determine the initial price.
    uint public constant INITIAL_MINIMUM = 10 ether; // Parameter for initial price.
    uint public constant MINIMUM_PERCENTAGE_INCREASE = 5; // Parameter for a 5% increase to the previous price.
    uint public constant EXTENSION_TERM = 10 minutes; // Parameter to extend the deadline.
    uint public constant EXTENDABLE_MARGIN = 10 minutes; // Parameter to extend the deadline by the last 10 minutes

    // Mapping for auction refunds.
    mapping(address => uint) public offersEarrings;
    
    // Structure that represents an offer
    struct Offer {
        uint amount;
    }

    // Mapping that associates each address with an offer.
    mapping(address => Offer) public offers;

    // Event statement for when a best offer emerges. Announces the bidder, the amount, and updates the auction end time.)
    event newBestOffer(address indexed bidder, uint _amount, uint newEnd);
    // Event statement for when the auction ends. Announces the winner and the amount.
    event auctionEnded(address winner, uint amount);

    // We use the constructor to initialize the owner, set the duration, and set the initial amount of the auction. 
    constructor() {
        owner = msg.sender;
        endAuction = block.timestamp + 5 minutes;
        bestOffer = INITIAL_MINIMUM;
    }

    // This modifier will prevent the same owner from being able to offer.
    modifier nonOwner(){
        require(msg.sender != owner, "The owner cannot offer");
        _;
    }
    
    // This modifier acts on the bid function. It determines whether an offer can be placed or not, taking into account the auction status and whether block.timestamp is less than endAuction.
    modifier onlyBeforeFinishing () {
        require(!finished, "The auction is now over."); // Requires that it not be finished.
        require(block.timestamp < endAuction, "The auction ended"); // Requires that the auction end be greater than the time of its creation. 
        _;
    }

    // This modifier acts on the endAuction function. It checks whether the auction has already ended. 
    modifier onlyAfterFinishing () {
        // check if the auction has already ended.
        require(block.timestamp >= endAuction,"The auction is still active");
        _;
    }

    address[] public bidders;

    // This function can only be called from outside the contract and is payable because it receives ether.
    function offer() external payable onlyBeforeFinishing nonOwner {
        // We declare a local variable to store the new valid value for offer, considering that if it is 5% greater than the current one.
        uint increaseRequired = (bestOffer * (100 + MINIMUM_PERCENTAGE_INCREASE)) / 100;
        // With the variable IncrementoRequired we restrict the bidder's value to be 5 times greater than the current price.
        require(msg.value >= increaseRequired, "The offer must exceed the current one by at least 5%.");
        // If this is the first time this bidder bids, add it to the array.
        if(offersEarrings[msg.sender] == 0){
            bidders.push(msg.sender);
        }

        // We updated the sender's offer
        offers[msg.sender] = Offer({
            amount: msg.value
        });

        // We keep the previous bidder's money so they can withdraw it if they are outbid by a new bid.
        if (highestBidder != address(0)) {
            offersEarrings[highestBidder] += bestOffer;
        }
        // We save the new bidder value and its amount, updating the auction time duration.
        highestBidder = msg.sender;
        bestOffer = msg.value;

        // Extension of the deadline if we are in the last 10 minutes before the end of the auction.
        if (endAuction - block.timestamp <= EXTENDABLE_MARGIN) {
            endAuction += EXTENSION_TERM;
        }

        // We issue the event with the new offer and amount, updating the new term length.
        emit newBestOffer(highestBidder, bestOffer, endAuction);
    }
    
    // Function to obtain the list of bidders and their amounts
    function getOffers() public view returns (address[] memory, uint[] memory) {
        uint[] memory amount = new uint[](bidders.length);
        for (uint i = 0; i < bidders.length; i++) {
            amount[i] = offers[bidders[i]].amount;
        }
        return (bidders, amount);
    }

    // This function will inform bidders how much time is left before the auction ends.
    function timeRemaining() public view returns (uint secondsRemaining) {
        if (block.timestamp > endAuction ) {
            return 0;
        } else {
            return endAuction - block.timestamp;
        }
    }
    
    // This feature allows bidders to make partial withdrawals if they have been outbid by another bid only while the auction is still open.
    function withdraw () external onlyBeforeFinishing{
        // check how much money the user calling the function has yet to withdraw.
        uint amount = offersEarrings[msg.sender];
        // If the amount is less than 0, it will display a message saying NOTHING TO WITHDRAW. It is reversed and does nothing.
        // This prevents unnecessary or malicious transfers. 
        require(amount > 0,"Nada para withdraw");

        // Now the record is reset to 0 to prevent re-entry.
        offersEarrings[msg.sender]=0;

        // Now we use call{value:amount}("") to transfer Ether, we could also use transfer(). but with call we avoid errors due to gas limits.
        // If the transfer fails, the success will be false. If the call fails, the entire transaction is reversed, and the user does not lose their right to withdraw.
        // This is because we set/modified the amount to 0 in the previous line.
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        // If the transfer was successful, we will refund the money from the bidder who made the auctions and increase the outstanding amounts by the sum of all the bids.
        require(success, "Fallo al enviar Ether");
    }

    // This function allows you to close the auction.
    function end_Auction() external onlyAfterFinishing {
        //We verify that the auction is not finished.
        require(!finished, "The auction is now over"); 
        // We verify that an offer has been made.
        require(bestOffer > 0, "No offers were made");

        // We changed the auction status to finished
        finished = true;
        // We broadcast the event with the winner and the amount with which they won the auction.
        emit auctionEnded(highestBidder, bestOffer);
    }
    
    // function to allow the owner to collect the winning bid and commissions for returning losing deposits.
    function collectOwnerFunds() external {
        require(msg.sender == owner, "Only the owner can collect funds");
        require(finished, "Auction must be finished");
        require(refundsProcessed, "Must refund losers first");
        
        uint amountToWithdraw = bestOffer + totalFeesCollected;
        totalFeesCollected = 0;

        (bool success, ) = payable(owner).call{value: amountToWithdraw}("");
        require(success, "Owner withdrawal failed");
    }

    // We created a variable flag.
    bool public refundsProcessed;

    // This feature allows the auctioneer to refund winning bids if partial withdrawal was not made before the auction ended.
    // The owner will keep 2% of the operating cost.
   function refundAllLosingBidders() external {
        require(msg.sender == owner, "Only the owner can call this");
        require(finished, "Auction must be finished");
        require(!refundsProcessed, "Refunds already processed");

        for (uint i = 0; i < bidders.length; i++) {
            address bidder = bidders[i];
            // Skip the highest bidder (winner)
            if (bidder == highestBidder) continue;
                uint amount = offersEarrings[bidder];

            if (amount > 0) {
                uint fee = (amount * 2) / 100;
                uint payout = amount - fee;

                offersEarrings[bidder] = 0;
                totalFeesCollected += fee;

                // Send refund to bidder
                (bool successPayout, ) = payable(bidder).call{value: payout}("");
                require(successPayout, "Failed to send refund to bidder");
            }
        }
        refundsProcessed = true;
    }
}
