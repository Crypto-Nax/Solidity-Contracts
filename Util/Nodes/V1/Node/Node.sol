// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./ControlledAccess.sol";
import "./ERC721Enumerable.sol";
import "./IUniswapV2Router02.sol";
import "./IERC20.sol";
import "./IRewardPool.sol";

contract Nodes is ERC721Enumerable, Ownable, ControlledAccess{
    using Strings for uint256;
    bool public autosell;
    string baseURI;
    string public baseExtension = ".json";
    uint256 public maxSupply = 10000000;
    uint256 constant public maxMintAmount = 5;
    uint256 constant public maxNodeAmount = 20;
    uint256 constant public limitsAfter = 5;
    uint256 public timeDeployed;
    uint256 public allowMintingAfter;
    IERC20 public Token;
    bool public isPaused;
    IRewardPool public rewardPool;
    IUniswapV2Router02 public uniswapV2Router;
    // tax in 1e4 (10000 = 100%)
    uint256 public tax;
    uint256 public mintPrice;
    mapping (address => uint256) waitTime;
    uint256 limitTime = 1 days;
    bool minting;
    modifier lockTheMint() {
        minting = true;
        _;
        minting = false;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        uint256 _revealTime,
        address T
    ) ERC721(_name, _symbol) {
        if (_revealTime > block.timestamp) {
            allowMintingAfter = _revealTime;
        }
        updateTokenAddress(T);
        updateTax(1500);
        updateMintPrice(20000000000); // 20*10**9
        timeDeployed = block.timestamp;
        setBaseURI(_initBaseURI);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Router = _uniswapV2Router;
        

    }

    receive() external payable {

  	}

    function toggleAutoSell(bool onoff) public  onlyOwner {
        autosell = onoff;
    }

    function updateMintPrice(uint256 price) public onlyOwner{
        mintPrice = price;
    }

    function setRewardPool(address _rewardPool) public onlyOwner{
        rewardPool = IRewardPool(_rewardPool);
    }

    function updateTax(uint256 _tax) public onlyOwner{
        require(_tax <= 1500);
        tax = _tax;
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function updateTokenAddress(address T) public onlyOwner{
        Token = IERC20(T);
    }

    function checkMint(uint256 amount, address _owner) internal returns(bool verified) {
        require(block.timestamp >= allowMintingAfter,"Minting now allowed yet");
        if(amount == 0) { verified = false; return verified;}
        require(amount <= maxMintAmount);
        uint256 supply = totalSupply();
        require(supply + amount <= maxSupply);
        require(balanceOf(_owner) + amount <= maxNodeAmount, "Max Node Amount Hit");
        require(!isPaused);
        if(minting){verified = true; return verified;}
        if(balanceOf(_owner) + amount <= limitsAfter) {
            if(balanceOf(_owner) + amount == limitsAfter){
                waitTime[_owner] = block.timestamp + limitTime;
            }
            verified = true;
        } else if (balanceOf(_owner) + amount > limitsAfter) {
            require(waitTime[_owner] < block.timestamp);
            require(amount == 1);
            waitTime[_owner] = block.timestamp + limitTime;
            verified = true;
        }
        return verified;
    }

    function mint_(uint256 mintAmount, address _owner) internal lockTheMint {
        checkMint(mintAmount, _owner);
        uint256 supply = totalSupply();

        uint256 price = mintPrice * mintAmount;
        uint256 _tax = (price*tax)/10000;

        if (msg.sender != owner()) {
            require(IERC20(Token).transferFrom(_owner, address(this), price), "Not enough funds");
            IERC20(Token).approve(address(uniswapV2Router), _tax);
            if (autosell) {
                swapTokensForEth(_tax);
            }
            IERC20(Token).transfer(address(rewardPool), price-_tax);
        }
        _safeMint(_owner, supply + mintAmount);
    }

    // public
    function mint(uint256 mintAmount) public payable {
        checkMint(mintAmount, msg.sender) ? mint_(mintAmount, msg.sender) : revert();
    }

       
    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function getSecondsUntilMinting() public view returns (uint256) {
        if (block.timestamp < allowMintingAfter) {
            return (allowMintingAfter) - block.timestamp;
        } else {
            return 0;
        }
    }


    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function setIsPaused(bool _state) public onlyOwner {
        isPaused = _state;
    }

    function swapTokensForEth(uint256 tokenAmount) private {

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(Token);
        path[1] = uniswapV2Router.WETH();

        IERC20(Token).approve(address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        
    }

    function sell(uint256 tokenAmount) public onlyOwner {

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(Token);
        path[1] = uniswapV2Router.WETH();

        IERC20(Token).approve(address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        if (from == address(0)) {
            IRewardPool(rewardPool).addNodeInfo(tokenId, to);        
        } else if (from != to) {
            IRewardPool(rewardPool).claimReward(tokenId);        
            IRewardPool(rewardPool).updateNodeOwner(tokenId, to);
        }
    }

    function claimRewards( address _owner) public {
        uint256[] memory tokens = walletOfOwner(_owner);
        for (uint256 i; i < tokens.length; i++) {
            IRewardPool(rewardPool).claimReward(tokens[i]);
        }
    }


    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }
}