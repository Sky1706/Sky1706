// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";



contract NftSecondarySellMarketPlace is Ownable ,IERC721Receiver,ReentrancyGuard{
    using SafeMath for uint256;
    IERC721 private erc721Token;

    struct Sale {
        uint256 tokenId;
        uint256 price;
        address erc20Token;
        address seller;
        bool onSale;
        bool sold;
        bool cancel;
    }

    struct Auction {
        uint256 tokenId;
        uint256 basePrice;
        address erc20Token;
        address auctioner;
        address[] bidders;
        address currentBidders;
        uint256 bidAmount;
        uint256 bidCount;
        bool onAuction;
        bool sold;
        bool auctionCancel;
        
    }

    event SaleNfts(
        uint256 indexed tokenId,
        uint256 indexed price,
        address erc20Token,
        address seller,
        address receiver
    );

    event CancelSaleAndUnSoldNfts (
        uint256 tokenId,
        address caller
    );

   
    event CreateAuction(
        uint256 indexed tokenId,
        uint256 basePrice,
        address erc20Token,
        address auctioner
    );

    event PlaceBid(
        address bidder, 
        uint256 price
    );

    event TokenTransfer(
        uint256 creatorsAmounts,
        uint256 sellerAmounts
    );



    uint256 public constant TYPE_SALE = 1;
    uint256 public constant TYPE_AUCTION = 2;
    uint256 public _sellTax;
    uint256 public _buyTax;

    /*
        @notice only admin and nft owner can cancel the sale
    */
    modifier onlyAdminAndNftOwner(uint256 tokenId){
        require(msg.sender == _msgSender() || erc721Token.ownerOf(tokenId) == msg.sender,"Only Admin and Nft Owner Allow");
        _;
    }

    mapping(uint256 => Sale) private mapSale;
    mapping(uint256 => Auction) private mapAuction;
    mapping(uint256 => mapping(address => uint256)) public fundsByBidders;
    mapping(uint256 => uint256) private saleStatus;
    // mapping (address => uint256) private _sellerBalance; pending

    /*
     * @notice Constructor
     * @param _erc721Token accept collection (nft contract) address
     */
    constructor(address _erc721Token) {
        erc721Token = IERC721(_erc721Token);
    }


    /*
     * @notice SellNfts add nfts on the sale
     * @param tokenid accept nft token id
     * @param price accept nft price
     * @param erc20Token accept erc20 token address for accepting multiple erc20 token for but nfts
     */
    function sellNfts(
        uint256 _tokenId,
        uint256 _price,
        address _erc20Token,
        address _seller
    ) public{
        require(
            _price > 0, 
            "Not Accept Zero Price"
        );

    //    require(erc721Token.isApprovedOrOwner(address(this), _tokenId), "ERC721: tokenId not approved to sell");

        setSaleDetails (_tokenId, _price, _erc20Token,_seller);       

    }

    /*
     * @notice SellNfts add nfts on the sale
     * @param starttime accept start time of sale
     * @param endtime accept end time of sale
     * @param tokenid accept nft token id
     * @param price accept nft price
     * @param erc20Token accept erc20 token address for accepting multiple erc20 token for but nfts
     */
    function setSaleDetails(
        uint256 _tokenId,
        uint256 _price,
        address _erc20Token,
        address _sellerAddress
    ) internal {
        Sale storage NftForSale = mapSale[_tokenId];
        require(NftForSale.onSale == false, "Token id already on sale");

        NftForSale.tokenId = _tokenId;
        NftForSale.price = _price;
        NftForSale.erc20Token = _erc20Token;
        NftForSale.seller = _sellerAddress;
        NftForSale.onSale = true;
        NftForSale.sold = false;

        emit SaleNfts(_tokenId, _price, _erc20Token, msg.sender,address(0));
    }

    /*
     * @notice get details of sell nfts using token id
     * @param starttime selling start time
     * @param endTime selling end time
     * @param tokenid accept nft token id
     * @param price accept nft price
     * @param erc20Token accept erc20 token address for accepting multiple erc20 token for but nfts
     * @param seller address give nfts seller address
     * @param onsale nfts is on sale or not
     * @param sold nfts is sold or not
     * @param cancel nfts is cancel or not
     */
    function getSale(uint256 tokenId)
        public
        view
        returns (
         
            uint256 _tokenId,
            uint256 _price,
            address _erc20Token,
            address _sellerAddress,
            bool _onSale,
            bool _sold,
            bool _cancel
        )
    {
        Sale storage NftForSale = mapSale[tokenId];
        return (
            _tokenId = NftForSale.tokenId,
            _price = NftForSale.price,
            _erc20Token = NftForSale.erc20Token,
            _sellerAddress = NftForSale.seller,
            _onSale = NftForSale.onSale,
            _sold = NftForSale.sold,
            _cancel = NftForSale.cancel
        );
    }

    /*
     * @notice this function is used to buy nfts using native crypto currency and multiple erc20 token
     * @param _tokenId use to buy nfts on sell
     */
    function buyNfts(uint256 _tokenId) public payable nonReentrant {
        require(
            msg.sender != IERC721(erc721Token).ownerOf(_tokenId),
            "Token Owner is not allowed to buy token"
        );

        Sale storage NftForSale = mapSale[_tokenId];


        require(NftForSale.onSale == true, "Token is not on sale");

        require(NftForSale.cancel == false, "Sale is cancel");

        if (
            NftForSale.erc20Token == address(0)
        ) {
            require(msg.value == NftForSale.price,"Amount is equal to Sale Price");
            (address user, uint256 royaltyAmount) = erc721Token.royaltyInfo(NftForSale.tokenId, NftForSale.price);
            tokenTransfer(NftForSale.price,royaltyAmount,NftForSale.erc20Token,msg.sender,NftForSale.seller,user);
            erc721Token.transferFrom(address(this), msg.sender, _tokenId);
            NftForSale.onSale = false;
            NftForSale.sold = true;

            emit SaleNfts(
                _tokenId,
                msg.value,
                address(0),
                NftForSale.seller,
                msg.sender
            );
        } else {
            require(IERC20(NftForSale.erc20Token).allowance(msg.sender,address(this)) == NftForSale.price,"Less allowance");
            IERC20(NftForSale.erc20Token).transferFrom(msg.sender,address(this),NftForSale.price);
            (address user, uint256 royaltyAmount) = erc721Token.royaltyInfo(NftForSale.tokenId, NftForSale.price);
            tokenTransfer(NftForSale.price,royaltyAmount,NftForSale.erc20Token,msg.sender,NftForSale.seller,user);

            erc721Token.transferFrom(address(this), msg.sender, _tokenId);
            NftForSale.sold = true;
            NftForSale.onSale = false;

            emit SaleNfts(
                _tokenId,
                NftForSale.price,
                NftForSale.erc20Token,
                NftForSale.seller,
                msg.sender
            );
        }
    }


    /*
     * @notice this function is used to cancel the sell
     * @param _tokenId use to cancel nfts on sell
     */
    function cancelSell(uint256 _tokenId) public onlyAdminAndNftOwner(_tokenId) {
        Sale storage NftForSale = mapSale[_tokenId];
        require(NftForSale.onSale == true, "Sale is not start");
        require(NftForSale.tokenId == _tokenId, "token id is not match");
        require(NftForSale.cancel == false, "Sell is already cancel");
        require(NftForSale.sold == false, "Nft is already sold");


        erc721Token.transferFrom(address(this),NftForSale.seller,_tokenId);

        delete mapSale[_tokenId];

        NftForSale.cancel = true;

        emit CancelSaleAndUnSoldNfts(_tokenId,msg.sender);
    }

    /*
        @notice This unsoldnfts is used to get back the nfts if is not sold
        @param _tokenId Nfts Tokenid
    */

    function unsoldNfts(uint256 _tokenId)public{
        Sale storage NftForSale = mapSale[_tokenId];
        require(msg.sender == NftForSale.seller,"Only Seller");
        require(NftForSale.sold == false,"Nfts Is Sold");

        erc721Token.transferFrom(address(this),msg.sender,_tokenId);
        NftForSale.onSale = false;

        emit CancelSaleAndUnSoldNfts(_tokenId,msg.sender);
    }

    /*
     * @notice SellNfts add nfts on the sale
     * @param starttime accept start time of sale
     * @param endtime accept end time of sale
     * @param tokenid accept nft token id
     * @param price accept nft price
     * @param erc20Token accept erc20 token address for accepting multiple erc20 token for but nfts
     */
    function createAuctions(
        uint256 _tokenId,
        uint256 _basePrice,
        address _erc20TokenAddress,
        address _auctioner
    ) public {
        
        require(_basePrice >= 0, "Baseprice is always gather then zero");
        // require(erc721Token.isApprovedOrOwner(address(this), _tokenId), "ERC721: tokenId not approved to sell");
        setAuctionDetails(
            _tokenId,
            _basePrice,
            _erc20TokenAddress,
            _auctioner
        );
    }

    /*
        @notice This SetAuctionDetails is used to set the auction details
    */
    function setAuctionDetails(
        uint256 _tokenId,
        uint256 _basePrice,
        address _erc20Token,
        address _auctioner
    ) internal {
        Auction storage StructAuction = mapAuction[_tokenId];
        StructAuction.tokenId = _tokenId;
        StructAuction.basePrice = _basePrice;
        StructAuction.erc20Token = _erc20Token;
        StructAuction.auctioner = _auctioner;
        StructAuction.onAuction = true;
        StructAuction.sold = false;
        StructAuction.auctionCancel = false;

        emit CreateAuction(
            _tokenId,
            _basePrice,
            _erc20Token,
            msg.sender
        );
    }

    /*
     * @notice this function is used to buy nfts using native crypto currency and multiple erc20 token
     * @param _tokenId use to buy nfts on sell
     */
    function getAuction(uint256 tokenId)
        external
        view
        returns (
            uint256 _tokenId,
            uint256 _basePrice,
            address _erc20TokenAddress,
            address _auactioner,
            bool _onAuction,
            bool _sold,
            bool _auctionCancel
        )
    {
        Auction storage StructAuction = mapAuction[tokenId];
        return (
            _tokenId = StructAuction.tokenId,
            _basePrice = StructAuction.basePrice,
            _erc20TokenAddress = StructAuction.erc20Token,
            _auactioner = StructAuction.auctioner,
            _onAuction = StructAuction.onAuction,
            _sold = StructAuction.sold,
            _auctionCancel = StructAuction.auctionCancel
        );
    }

    /*
     * @notice this function is used to place the bid on the nfts using native cryptocurrency and multiple erc20 token
     * @param _tokenId use to bid on nfts
     * @param _price is used to bid on nfts
     */

    function placeBid(uint256 _tokenId, uint256 _price) public payable {
        require(_price > 0, "_price should be gather then zero");
        Auction storage StructAuction = mapAuction[_tokenId];

        require(
            StructAuction.onAuction == true,
            "This token id is not on auction"
        );

        require(
            _price >= StructAuction.basePrice,
            "_price should be gather then auction base price"
        );

        require(StructAuction.auctionCancel == false, "Auction is cancel");

        if (StructAuction.erc20Token == address(0)) {
            require(
                _price > StructAuction.bidAmount,
                "The price is less then the previous bid amount"
            );
            require(
                msg.value == _price, 
                "Msg value and price should be same"
            );
            require(
                msg.value > StructAuction.bidAmount,
                "Msg value should be gather then bidamount"
            );
            if(StructAuction.bidCount > 0){
                payable(StructAuction.currentBidders).transfer(fundsByBidders[_tokenId][StructAuction.currentBidders]);
            }
            StructAuction.bidAmount = _price;
            StructAuction.bidders.push(msg.sender);
            fundsByBidders[_tokenId][msg.sender]=fundsByBidders[_tokenId][msg.sender]+_price;
            StructAuction.currentBidders = msg.sender;
            StructAuction.bidCount++;

        } else {
            require(
                _price > StructAuction.bidAmount,
                "The price is less then the previous bid amount"
            );
            uint256 checkAllowance = IERC20(StructAuction.erc20Token).allowance(
                msg.sender,
                address(this)
            );
            require(checkAllowance >= _price, "Please give allowance");
            IERC20(StructAuction.erc20Token).transferFrom(
                msg.sender,
                address(this),
                _price
            );
            if(StructAuction.bidCount > 0)
            {
                IERC20(StructAuction.erc20Token).transfer(StructAuction.currentBidders,fundsByBidders[_tokenId][StructAuction.currentBidders]);
            }
            StructAuction.bidAmount = _price;
            StructAuction.bidders.push(msg.sender);
            fundsByBidders[_tokenId][msg.sender] = fundsByBidders[_tokenId][msg.sender] + _price;
            StructAuction.currentBidders = msg.sender;
            StructAuction.bidCount++;
        }
        emit PlaceBid(msg.sender,_price);
    }

    //this function is used to claim erc721 token(nfts)
    function claimNfts(uint256 _tokenId) public {
        Auction storage StructAuction = mapAuction[_tokenId];
        require(
            msg.sender == StructAuction.currentBidders,
            "You are not a highest bidders"
        );
        require(
            StructAuction.auctionCancel == false,
            "This token id auction is cancel"
        );
        (address user,uint256 royaltyAmount) = erc721Token.royaltyInfo(StructAuction.tokenId,StructAuction.basePrice);
        tokenTransfer(fundsByBidders[_tokenId][msg.sender],royaltyAmount,StructAuction.erc20Token,msg.sender,StructAuction.auctioner,user);
        erc721Token.transferFrom(
            address(this),
            StructAuction.currentBidders,
            _tokenId
        );
        StructAuction.onAuction = false;
        StructAuction.sold = true;
    }

    /*
     * @notice this function is used to know the balance of the smart contract
     */
    function balanceOfContract() public view returns (uint256) {
        return (address(this).balance);
    }

    /*
     * @notice this function is used to cancel the auction
     * @param _tokenId use to cancel the auction
     */

    function cancelAuction(uint256 _tokenId) external onlyAdminAndNftOwner(_tokenId) {
        Auction storage StructAuction = mapAuction[_tokenId];
        require(
            StructAuction.tokenId == _tokenId,
            "Token id is not on auction"
        );
        require(StructAuction.onAuction == true, "Token id is not on auction");
        require(
            StructAuction.auctionCancel == false,
            "Auction is already cancel"
        );

        require(StructAuction.sold == false, "Already sold");

        StructAuction.onAuction = false;
        StructAuction.auctionCancel = true;

        delete mapAuction[_tokenId];
    }

    /*
        @notice this unSoldAuctionNfts Function is used to get back nfts from the marketplace and only auctioner can call this function
        @param _tokenId Nfts Token id
    */
    function unSoldAuctionNfts(uint256 _tokenId)public{
        Auction storage StructAuction = mapAuction[_tokenId];
        require(msg.sender == StructAuction.auctioner,"Only Auctioner");
        require(StructAuction.sold == false,"Auction Nfts Is Sold");
        
        erc721Token.transferFrom(address(this),msg.sender,_tokenId);

        StructAuction.onAuction = false;

        emit CancelSaleAndUnSoldNfts(_tokenId,msg.sender);

    }

    /*
        @notice This onERC721Received function is used to decode the sale
                and auction data and used to start the auction and sale
                when hit the safetransferfrom function from Erc721 Contracts

        @param _from token sender address
        @param _to token reciver address
        @param _tokenId nfts id
        @param _data bytes data from safetransfer from function
    */
    function onERC721Received(address _from,address _to,uint256 _tokenId,bytes memory _data)public virtual override returns(bytes4){

        (uint256 tokenId,uint256 price,uint256 basePrice,address erc20Token,uint256 saleType,address sellerAndAuctioner) = abi.decode(
            _data,
            (uint256,uint256,uint256,address,uint256,address)
            );

        if(saleType == 1){
            sellNfts(tokenId,
            price,
            erc20Token,
            sellerAndAuctioner);
        }
        else if(saleType == 2){
            createAuctions(
                tokenId,
                basePrice,
                erc20Token,
                sellerAndAuctioner
            );
        }
        else{
            require(
                saleType == TYPE_SALE || saleType == TYPE_AUCTION,
                "Invalid Type" 
            );
        }
        return(this.onERC721Received.selector);
    } 


     /* owner can set selltax(fees) */
    function setSellTax(uint256 percentage) external onlyOwner{
        _sellTax = percentage;
    }

    /* owner can set buytax(fees) */
    function setBuyTax(uint256 percentage) external onlyOwner{
        _buyTax = percentage;
    }


    function tokenTransfer(uint256 _price,uint256 _royaltyAmount,address _token,address _buyer,address _seller,address _royaltyReceiver)internal{
        if(_token == address(0)){
            require(_sellTax > 0,"Sell tax is zero");
            require(_buyTax > 0,"Buy tax is zero");
            
            uint256 adminAmounts = _price.mul(_sellTax).div(10000);
            uint256 countSellerAmouts = _price.sub(_royaltyAmount + adminAmounts);
            
            console.log(_royaltyAmount,adminAmounts,countSellerAmouts);

            payable(_royaltyReceiver).transfer(_royaltyAmount);
            payable(owner()).transfer(adminAmounts);
            payable(_seller).transfer(countSellerAmouts);
            

            emit TokenTransfer(_royaltyAmount,countSellerAmouts);
        }
        else{
            require(_sellTax > 0,"Sell tax is zero");
            require(_buyTax > 0,"Buy tax is zero");

            // uint256 creatorsAmounts = _price.mul(_buyTax).div(10000);
            uint256 adminAmounts = _price.mul(_sellTax).div(10000);
            uint256 countSellerAmouts = _price.sub(_royaltyAmount + adminAmounts);


            IERC20(_token).transfer(_royaltyReceiver,_royaltyAmount);
            IERC20(_token).transfer(owner(),adminAmounts);
            IERC20(_token).transfer(_seller,countSellerAmouts);

            emit TokenTransfer(_royaltyAmount,countSellerAmouts);
        }
    }

}



