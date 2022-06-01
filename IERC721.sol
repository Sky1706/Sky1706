// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IERC721{
    function ownerOf(uint256 tokenId)external view returns(address);
    function artist(uint256 tokenId)external view returns(address);
    function mint(address to,uint256 tokenId)external;
    function transferFrom(address from,address to,uint256 tokenId)external;
    function getArtist(uint256 _tokenId)external view returns(uint256);
    function royaltyInfo(uint256 _tokenId,uint256 _price)external view returns(address,uint256);
    function isApprovedOrOwner(address spender, uint256 tokenId)external view returns(bool);
    function allowance(address spender,address to)external view returns(uint256);
}