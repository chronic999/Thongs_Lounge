// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

/*
    ░█████╗░██████╗░██╗░░░██╗██████╗░████████╗░█████╗░███╗░░██╗██╗░█████╗░
    ██╔══██╗██╔══██╗╚██╗░██╔╝██╔══██╗╚══██╔══╝██╔══██╗████╗░██║██║██╔══██╗
    ██║░░╚═╝██████╔╝░╚████╔╝░██████╔╝░░░██║░░░██║░░██║██╔██╗██║██║██║░░╚═╝
    ██║░░██╗██╔══██╗░░╚██╔╝░░██╔═══╝░░░░██║░░░██║░░██║██║╚████║██║██║░░██╗
    ╚█████╔╝██║░░██║░░░██║░░░██║░░░░░░░░██║░░░╚█████╔╝██║░╚███║██║╚█████╔╝
    ░╚════╝░╚═╝░░╚═╝░░░╚═╝░░░╚═╝░░░░░░░░╚═╝░░░░╚════╝░╚═╝░░╚══╝╚═╝░╚════╝░

    ░█████╗░██╗░░██╗██████╗░░█████╗░███╗░░██╗██╗░█████╗░
    ██╔══██╗██║░░██║██╔══██╗██╔══██╗████╗░██║██║██╔══██╗
    ██║░░╚═╝███████║██████╔╝██║░░██║██╔██╗██║██║██║░░╚═╝
    ██║░░██╗██╔══██║██╔══██╗██║░░██║██║╚████║██║██║░░██╗
    ╚█████╔╝██║░░██║██║░░██║╚█████╔╝██║░╚███║██║╚█████╔╝

    This contract is designed to be used as a simple nft collection contract in partnership with Thongs Lounge,
    and may be used by anyone for similar purposes. Cryptonic chronic takes absolutely no responisibility
    for anyone who uses this contract for malicious purposes, or any losses that may occur,
    please do not copy and paste any contracts you do not fully understand as it could lead
    to losses for you and your project. it is always best to assume all contracts are unsafe until fully
    reviewing the code and testing before deployment yourself. no funds are stored on this contract...
    please enjoy, happy coding
*/

contract Thongs_AI is ERC721, ERC721URIStorage, ERC2981 {

    // global variables
    address payable public contractOwner;
    address payable public royaltyAddress;
    bool private locked; // this is for modifier function
    bool public paused = true; // contract must be unpaused before minting items
    uint public mintFee = 1 *10**18 wei; // total cost 1 polygon/matic per tx converted to wei, can be changed to any price, ex. 2.5, 4.753, etc
    uint public royaltyFee = 200; // this is set to 2% in basis points(1 x 100 = 100bps), same as opensea check their docs to find out more
    uint public tokenSupply = 1000; // change this to the same amount of images available to mint
    uint public tokenId; // this is the amount of tokens minted
    uint public deploymentDate; // date contract deployed in UNIX

    mapping(uint => string) private _tokenURIs; // sets new metadata URI path for nft
    mapping(uint => uint) private royaltyFees;
    mapping(uint => address) public Buyer;

    struct Purchased{
        uint itemId;
        address nftBuyer;
        uint purchaseDate;
        string tokenURI;
    }

    // constructor function sets data, is only run one time during initial deployment
    constructor(address _royaltyAddress) ERC721("Thongs AI NFTs", "TLT") {
        contractOwner = payable(msg.sender); //this sets contract deployer to contract owner
        royaltyAddress = payable(_royaltyAddress); // this sets the royalty receiver for the collection
        deploymentDate = block.timestamp; // sets date of deployment
    }

    // modifer functions for controlling contract for owner
    modifier Paused() {
        require(paused, "contract must be paused");
        _;
    }

    modifier unPaused() {
        require(!paused, "contract must be paused");
        _;
    }

    modifier preventReentrant() {
        require(!locked, "reentrancy avoided");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOwner() {
        require(msg.sender == contractOwner, "not contract owner");
        _;
    }

    // main contract functions

    function setPause() public onlyOwner {
        bool _state = paused;

        if(!_state) {
            _state = true;
        } else {
            _state = false;
        }

        paused = _state;
        /*
         @dev this function pauses contract incase of emergency
        but is only callable by contract owner and no one else,
        all setter functions cost gas fees to caller.
        */
    }

    function mintNFT(uint _mintAmount, string memory _tokenURI) public payable preventReentrant unPaused {
        uint _cost = msg.value;
        address _buyer = msg.sender;
        uint tokenCount = tokenId;
        uint itemRoyalties = _cost / 10000 * royaltyFee;
        uint saleProfit = _cost - itemRoyalties;

        require(_mintAmount > 0, "mint > 0");
        require(_mintAmount + tokenCount <= tokenSupply, "sold out");

        if (msg.sender != contractOwner) {
            require(_cost >= mintFee * _mintAmount, "not enough funds to mint");
            // this allows ocntract owner to mint nfts for free
        }
        
        if (_mintAmount > 1){
            for (uint i = 0; i <= _mintAmount; i++) {
                uint tokenIds = i + tokenCount;
                Buyer[tokenIds] = _buyer;
                royaltyFees[tokenIds];
                _safeMint(_buyer, tokenIds);
                _setTokenURI(tokenIds, _tokenURI);
                tokenId = tokenIds;
            }
        } else {
            tokenCount++;
            uint newTokenId = tokenCount;
            _safeMint(_buyer, newTokenId);
            Buyer[newTokenId] = _buyer;
            royaltyFees[newTokenId] = royaltyFee;
            _setTokenURI(newTokenId, _tokenURI);
            tokenId = newTokenId;
        }

        contractOwner.transfer(saleProfit);
        royaltyAddress.transfer(itemRoyalties);

    }

    function BurnNFT(uint _itemId) public unPaused {
        require(msg.sender == Buyer[_itemId], "not nft owner");
        _burn(_itemId);
        // this function calls internal burn and sends NFT to zero address,
        // once called item is gone forever, please be certain on token id.
    }
        
    function _burn(uint256 _itemId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(_itemId);
    }

    function tokenURI(uint256 _tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        _requireMinted(_tokenId);
        string memory _tokenURI = _tokenURIs[_tokenId];
        string memory base = _baseURI();
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        return super.tokenURI(_tokenId);
    }

    function setNewURI(uint _itemId, string memory _newURI) public unPaused {
        require(msg.sender == contractOwner, "not original artist");
        _setTokenURI(_itemId, _newURI);
        // for setting new metadata pathway for ipfs json files.
    }

    function getUnsoldCount() public view returns(uint tokensLeft) {
        tokensLeft = tokenSupply - tokenId;
        // function calculates amount left to be minted
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function royaltyInfo(uint256 _itemId, uint _salePrice) public view override returns (address receiver, uint256 royaltyAmount) {
        receiver = royaltyAddress;
        royaltyAmount = (_salePrice / 10000) * royaltyFees[_itemId];
        // this implements the erc2981 contract for royalties
        // this is enforced by opensea and and any other markets
        // that have implemented the standard.
        // salePrice var is set when called from external contract
    }
}