//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Cash is ERC20("Autono USD", "USDA") {
    address public minter;

    uint256 private lastWeekAvgSupply;
    uint256 private lastUpdateTs;

    mapping(address => uint256) private _nonces;

    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    bytes32 private constant _domainSeparatorV4 =
        keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("Autono USD"),
                keccak256("1"),
                uint256(1),
                address(0xB6736DcDa3AA3bDBb1E67b9F59B7c977D39b99B8)
            )
        );

    function init(address _minter) external {
        require(minter == address(0));
        minter = _minter;
    }

    function mint(address to, uint amount) external {
        require(msg.sender == minter, "error");
        updateSupply();
        _mint(to, amount);
    }

    function burn(address from, uint amount) external {
        _spendAllowance(from, msg.sender, amount);
        updateSupply();
        _burn(from, amount);
    }

    function updateSupply() public {
        uint256 period = 1 weeks;
        uint256 curTotalSupply = totalSupply();

        uint256 tmpTime = block.timestamp - lastUpdateTs;
        if (tmpTime == 0) {
            return;
        }

        if (tmpTime >= period) {
            lastWeekAvgSupply = totalSupply();
            lastUpdateTs = block.timestamp;
            return;
        }

        lastWeekAvgSupply =
            (lastWeekAvgSupply *
                (period - tmpTime) +
                curTotalSupply *
                (tmpTime)) /
            period;
        lastUpdateTs = block.timestamp;
    }

    function lastWeekAvgTvl() external view returns (uint256) {
        uint256 period = 1 weeks;
        uint256 curTotalSupply = totalSupply();

        uint256 tmpTime = block.timestamp - lastUpdateTs;
        if (tmpTime >= period) {
            return curTotalSupply;
        } else {
            return
                (lastWeekAvgSupply *
                    (period - tmpTime) +
                    curTotalSupply *
                    tmpTime) / period;
        }
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _nonces[owner],
                deadline
            )
        );
        _nonces[owner] += 1;

        bytes32 hash = ECDSA.toTypedDataHash(_domainSeparatorV4, structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "ERC20Permit: invalid signature");

        _approve(owner, spender, value);
    }

    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner];
    }

    function name() public view virtual override returns (string memory) {
        return "Autono USD";
    }

    function symbol() public view virtual override returns (string memory) {
        return "USDA";
    }

    function version() public pure returns (string memory) {
        return "1";
    }
}
