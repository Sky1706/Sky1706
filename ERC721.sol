// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract NFTERC721 is ERC721,IERC2981{
    using SafeMath for uint256;
    struct Royalty{
        address creator;
        uint256 royaltyFractions;
    }

    mapping(uint256 => Royalty)public royaltyInformation;
    mapping(uint256 => address)public artist;


    constructor()ERC721("Accubits","Accubits"){
    }
    function mint(address _to,uint256 _tokenId,uint256 _royaltyFractions,address _royaltyReceiver)public{
        _mint(_to,_tokenId);
        royaltyInformation[_tokenId].creator = _royaltyReceiver;
        royaltyInformation[_tokenId].royaltyFractions = _royaltyFractions;
        artist[_tokenId] = _to;
    }

    function royaltyInfo(uint256 tokenId,uint256 salePrice)public view returns(address,uint256){
        Royalty storage _royalty = royaltyInformation[tokenId];
        uint256 royaltyAmount = salePrice.mul(_royalty.royaltyFractions).div(10000);
        return (
            _royalty.creator,
            royaltyAmount
        );
    }
    //this function is used to get the artists
    function getArtist(uint256 _tokenId)public view returns(address){
        require(_isExists(_tokenId),"Token id is not minted");
        return (artist[_tokenId]);
    }
    //this function is used to check the tokenid is exists or not
    function _isExists(uint256 _tokenId)public view returns(bool){
            return(_exists(_tokenId));
    }
        function isApprovedOrOwner(address spender, uint256 tokenId) public view returns(bool){
        return _isApprovedOrOwner(spender, tokenId);
    }
}