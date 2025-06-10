- Solidity Auction Contract
- Description
This project is a smart contract for a sealed-bid auction, written in Solidity. It allows users to place increasing bids, tracks the highest bidder, and handles refunding the losing participants with a 2% commission to the contract owner.

It ensures safe auction execution, secure withdrawals, and protects against common vulnerabilities in Ethereum smart contracts.

- Contract Overview
- General
Contract Name: Auction

Solidity Version: ^0.8.30

License: MIT

- Roles
owner: The auction creator who manages the auction and collects commissions.

bidders: Anyone except the owner can bid in the auction.

highestBidder: The current highest bidder (the winner if the auction ends).

- State Variables
Variable	Type	Description
owner	address	The owner (deployer) of the contract.
highestBidder	address	Current leading bidder.
endAuction	uint	Timestamp of auction end.
totalFeesCollected	uint	Accumulated 2% commission from refunds.
bestOffer	uint	Highest current bid.
finished	bool	Indicates if the auction is finished.
refundsProcessed	bool	Flags if refunds to losers have already been processed.
bidders	address[]	List of all bidders.
offersEarrings	mapping	Tracks refundable bids (for losing bidders).
offers	mapping	Stores each bidder’s current offer.

- Constants
Constant	Value	Description
INITIAL_MINIMUM	10 ether	Starting price for the auction.
MINIMUM_PERCENTAGE_INCREASE	5	Minimum percentage increase for a new bid.
EXTENSION_TERM	10 minutes	Auction time extension in last moments.
EXTENDABLE_MARGIN	0 minutes	Time before auction end that allows extension (currently disabled).

# Key Functions
* offer()
Allows users to submit a bid that is at least 5% higher than the current best offer.

Tracks bidders and updates offersEarrings for refunds to previous highest bidders.

* withdraw()
Allows partial or full refunds for users who have been outbid.

Can only be called while the auction is ongoing.

Ensures no reentrancy by zeroing the balance before sending funds.

* end_Auction()
Can only be called after the auction end time.

Marks the auction as finished and emits the winner.

* refundAllLosingBidders()
Called by the owner after auction ends.

Refunds all losing bidders (except the winner), keeping 2% commission.

Updates totalFeesCollected for later withdrawal.

Prevents double refunds using the refundsProcessed flag.

* collectOwnerFunds()
Allows the owner to collect the winning bid + total 2% fees.

Requires that refundAllLosingBidders() has already run.

Prevents premature fund grabbing by requiring refundsProcessed == true.

* getOffers() / timeRemaining()
getOffers() returns a list of bidders and their offer amounts.

timeRemaining() shows time left before auction ends.

- Security and Vulnerability Protections
Vulnerability	Mitigation Strategy
Reentrancy attacks	Updates balances before sending ETH in withdraw() and refundAllLosingBidders().
Unauthorized access	Only owner can call critical functions using require(msg.sender == owner)
Front-running / bid sniping	Optionally supports deadline extension via EXTENSION_TERM (currently disabled).
Double refunds	Controlled by refundsProcessed flag.
Incorrect fund collection	collectOwnerFunds() blocked until refunds are processed.
Gas griefing / denial	Refunds are iterated carefully and could be optimized further for scalability.

- Usage Flow
Deployment: Owner deploys the contract; auction starts immediately.

Bidding: Participants call offer() with ETH.

Withdrawal (Optional): Losing bidders can call withdraw() before the auction ends.

End Auction: Owner or anyone calls end_Auction() after deadline.

Refund Losers: Owner runs refundAllLosingBidders() to process unclaimed refunds.

Owner Collects: Owner calls collectOwnerFunds() to get winning bid + fees.

- Requirements
Ethereum-compatible wallet (e.g. MetaMask)

Solidity ^0.8.0 (reentrancy-safe)

Etherscan or Remix for deployment and interaction

- License
MIT © 2025 — González Joaquín
