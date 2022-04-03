//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FairNFT is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private tokenCounter;

    string private BASEURI;
    string public PROVENANCE_HASH;
    uint256 public REVEAL_TIMESTAMP;
    uint256 public MAX_NFTS_PER_WALLET;
    uint256 public MAX_NFTS;

    uint256 startingIndex;
    uint256 startingIndexBlock;

    uint256 public constant PRESALE_PRICE = 0.05 ether;
    bool preSaleIsActive;
    uint256 public constant PUBLIC_SALE_PRICE = 0.08 ether;
    bool public publicSaleIsActive;

    uint8 public MAX_WHITELISTED_ADDRESSES;
    uint8 public numWhitelistedAddresses;
    address tokenManager;
    TokenContract public tokenContract;

    // ======= MODIFIERS ========== //

    modifier preSaleActive() {
        require(preSaleIsActive, "Pre sale is not active yet");
        _;
    }

    modifier publicSaleActive() {
        require(publicSaleIsActive, "Public sale is not active yet");
        _;
    }

    modifier canMintNfts(uint256 numOfTokens) {
        require(
            tokenCounter.current() + numOfTokens < MAX_NFTS,
            "Not enough NFTs to mint"
        );
        _;
    }

    modifier isCorrectAmount(uint256 price, uint256 numOfTokens) {
        require(
            msg.value > price * numOfTokens,
            "Insufficient amount of Ether"
        );
        _;
    }

    modifier maxPerWallet(uint256 numOfTokens) {
        require(
            balanceOf(msg.sender) + numOfTokens < MAX_NFTS_PER_WALLET,
            "You have minted the maximum number of nfts"
        );
        _;
    }

    // ===== MAPPINGS ====== //
    mapping(address => bool) public whitelistedAddresses;

    constructor(
        string memory _provenanceHash,
        uint256 _maxPerWallet,
        uint8 _maxWhitelistedAddresses
    ) ERC721("NFTName", "TICKER") {
        uint256 saleStart = block.timestamp;
        PROVENANCE_HASH = _provenanceHash;
        REVEAL_TIMESTAMP = saleStart + (86400 * 28);
        MAX_NFTS_PER_WALLET = _maxPerWallet;
        MAX_WHITELISTED_ADDRESSES = _maxWhitelistedAddresses;
    }

    // ======== PUBLIC FUNCTIONS ======== //

    function mint(uint256 _numOfTokens)
        external
        payable
        nonReentrant
        publicSaleActive
        canMintNfts(_numOfTokens)
        maxPerWallet(_numOfTokens)
        isCorrectAmount(PUBLIC_SALE_PRICE, _numOfTokens)
    {
        for (uint256 i; i < _numOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }

        if (
            startingIndexBlock == 0 &&
            (tokenCounter.current() == MAX_NFTS ||
                block.timestamp >= REVEAL_TIMESTAMP)
        ) {
            startingIndexBlock = block.number;
        }
    }

    function mintPreSale(uint256 _numOfTokens)
        external
        payable
        nonReentrant
        preSaleActive
        canMintNfts(_numOfTokens)
        maxPerWallet(_numOfTokens)
        isCorrectAmount(PRESALE_PRICE, _numOfTokens)
    {
        require(whitelistedAddresses[msg.sender]);
        for (uint256 i; i < _numOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }

    function setStartingIndex() public {
        require(startingIndex == 0, "Starting index has already been set");
        require(startingIndexBlock != 0, "Starting index block must be set");

        startingIndex = uint256(blockhash(startingIndexBlock)) % MAX_NFTS;

        if ((block.number - startingIndexBlock) > 255) {
            startingIndex = uint256(blockhash(block.number - 1)) % MAX_NFTS;
        }

        if (startingIndex == 0) {
            startingIndex += 1;
        }
    }

    // ======== ADMIN FUNCTIONS ======== //

    function setBaseURI(string memory _baseURI) external onlyOwner {
        BASEURI = _baseURI;
    }

    function setTokenManager(address _manager) external onlyOwner {
        tokenManager = _manager;
    }

    function flipPreSaleState() external onlyOwner {
        preSaleIsActive = !preSaleIsActive;
    }

    function flipPublicSaleState() external onlyOwner {
        publicSaleIsActive = !publicSaleIsActive;
    }

    function reserveTokens(uint256 reserveNumber)
        external
        nonReentrant
        onlyOwner
        canMintNfts(reserveNumber)
    {
        for (uint256 i; i < reserveNumber; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }

    function giftToken(address[] calldata addressList)
        external
        nonReentrant
        onlyOwner
        canMintNfts(addressList.length)
    {
        uint256 numOfGifts = addressList.length;
        for (uint256 i; i < numOfGifts; i++) {
            _safeMint(addressList[i], nextTokenId());
        }
    }

    function whiteListAddresses(address[] calldata addressList)
        external
        onlyOwner
    {
        require(
            addressList.length + numWhitelistedAddresses <
                MAX_WHITELISTED_ADDRESSES
        );
        for (uint256 i; i < addressList.length; i++) {
            whitelistedAddresses[addressList[i]] = true;
            numWhitelistedAddresses += 1;
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool sent, ) = (msg.sender).call{value: balance}("");
        require(sent, "Failed to withdraw");
    }

    function emergencySetStartingIndex() external onlyOwner {}

    function setTokenContract(address _contract) external onlyOwner {
        tokenContract = _contract;
    }

    // ======= HELPER FUNCTIONS ======== //
    function nextTokenId() private returns (uint256) {
        tokenCounter.increment();
        return tokenCounter.current();
    }
}
