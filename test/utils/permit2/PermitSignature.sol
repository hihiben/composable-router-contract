// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IAllowanceTransfer} from 'permit2/interfaces/IAllowanceTransfer.sol';
import {ISignatureTransfer} from 'permit2/interfaces/ISignatureTransfer.sol';

contract PermitSignature is Test {
    bytes32 public constant _PERMIT_DETAILS_TYPEHASH =
        keccak256('PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)');

    bytes32 public constant _PERMIT_SINGLE_TYPEHASH =
        keccak256(
            'PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)'
        );

    bytes32 public constant _PERMIT_BATCH_TYPEHASH =
        keccak256(
            'PermitBatch(PermitDetails[] details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)'
        );

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256('TokenPermissions(address token,uint256 amount)');

    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH =
        keccak256(
            'PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)'
        );

    bytes32 public constant _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH =
        keccak256(
            'PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)'
        );

    function getPermitSignatureRaw(
        IAllowanceTransfer.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 permitHash = keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, permit.details));

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                '\x19\x01',
                domainSeparator,
                keccak256(abi.encode(_PERMIT_SINGLE_TYPEHASH, permitHash, permit.spender, permit.sigDeadline))
            )
        );

        (v, r, s) = vm.sign(privateKey, msgHash);
    }

    function getPermitSignature(
        IAllowanceTransfer.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);
        return bytes.concat(r, s, bytes1(v));
    }

    function getCompactPermitSignature(
        IAllowanceTransfer.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);
        bytes32 vs;
        (r, vs) = _getCompactSignature(v, r, s);
        return bytes.concat(r, vs);
    }

    function getCompactPermitTransferSignature(
        ISignatureTransfer.PermitTransferFrom memory permit,
        address spender,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                '\x19\x01',
                domainSeparator,
                keccak256(
                    abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, spender, permit.nonce, permit.deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes32 vs;
        (r, vs) = _getCompactSignature(v, r, s);
        return bytes.concat(r, vs);
    }

    function _getCompactSignature(
        uint8 vRaw,
        bytes32 rRaw,
        bytes32 sRaw
    ) internal pure returns (bytes32 r, bytes32 vs) {
        uint8 v = vRaw - 27; // 27 is 0, 28 is 1
        vs = bytes32(uint256(v) << 255) | sRaw;
        return (rRaw, vs);
    }

    function getPermitBatchSignature(
        IAllowanceTransfer.PermitBatch memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32[] memory permitHashes = new bytes32[](permit.details.length);
        for (uint256 i = 0; i < permit.details.length; ++i) {
            permitHashes[i] = keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, permit.details[i]));
        }
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                '\x19\x01',
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_BATCH_TYPEHASH,
                        keccak256(abi.encodePacked(permitHashes)),
                        permit.spender,
                        permit.sigDeadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitTransferSignature(
        ISignatureTransfer.PermitTransferFrom memory permit,
        address spender,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                '\x19\x01',
                domainSeparator,
                keccak256(
                    abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, spender, permit.nonce, permit.deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitWitnessTransferSignature(
        ISignatureTransfer.PermitTransferFrom memory permit,
        address spender,
        uint256 privateKey,
        bytes32 typehash,
        bytes32 witness,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                '\x19\x01',
                domainSeparator,
                keccak256(abi.encode(typehash, tokenPermissions, spender, permit.nonce, permit.deadline, witness))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitBatchTransferSignature(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        address spender,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32[] memory tokenPermissions = new bytes32[](permit.permitted.length);
        for (uint256 i = 0; i < permit.permitted.length; ++i) {
            tokenPermissions[i] = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted[i]));
        }
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                '\x19\x01',
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                        keccak256(abi.encodePacked(tokenPermissions)),
                        spender,
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitBatchWitnessSignature(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        address spender,
        uint256 privateKey,
        bytes32 typeHash,
        bytes32 witness,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32[] memory tokenPermissions = new bytes32[](permit.permitted.length);
        for (uint256 i = 0; i < permit.permitted.length; ++i) {
            tokenPermissions[i] = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted[i]));
        }

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                '\x19\x01',
                domainSeparator,
                keccak256(
                    abi.encode(
                        typeHash,
                        keccak256(abi.encodePacked(tokenPermissions)),
                        spender,
                        permit.nonce,
                        permit.deadline,
                        witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function defaultERC20PermitAllowance(
        address token0,
        uint160 amount,
        address spender,
        uint48 expiration,
        uint48 nonce
    ) internal view returns (IAllowanceTransfer.PermitSingle memory) {
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer.PermitDetails({
            token: token0,
            amount: amount,
            expiration: expiration,
            nonce: nonce
        });
        return
            IAllowanceTransfer.PermitSingle({details: details, spender: spender, sigDeadline: block.timestamp + 100});
    }

    function defaultERC20PermitBatchAllowance(
        address[] memory tokens,
        uint160[] memory amounts,
        address spender,
        uint48 expiration,
        uint48 nonce
    ) internal view returns (IAllowanceTransfer.PermitBatch memory) {
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: tokens[i],
                amount: amounts[i],
                expiration: expiration,
                nonce: nonce
            });
        }

        return IAllowanceTransfer.PermitBatch({details: details, spender: spender, sigDeadline: block.timestamp + 100});
    }

    function defaultERC20PermitTransfer(
        address token0,
        uint256 amount,
        uint256 nonce
    ) internal view returns (ISignatureTransfer.PermitTransferFrom memory) {
        return
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({token: token0, amount: amount}),
                nonce: nonce,
                deadline: block.timestamp + 100
            });
    }

    function defaultERC20PermitWitnessTransfer(
        address token0,
        uint256 amount,
        uint256 nonce
    ) internal view returns (ISignatureTransfer.PermitTransferFrom memory) {
        return
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({token: token0, amount: amount}),
                nonce: nonce,
                deadline: block.timestamp + 100
            });
    }

    function defaultERC20PermitMultiple(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256 nonce
    ) internal view returns (ISignatureTransfer.PermitBatchTransferFrom memory) {
        ISignatureTransfer.TokenPermissions[] memory permitted = new ISignatureTransfer.TokenPermissions[](
            tokens.length
        );
        for (uint256 i = 0; i < tokens.length; ++i) {
            permitted[i] = ISignatureTransfer.TokenPermissions({token: tokens[i], amount: amounts[i]});
        }
        return
            ISignatureTransfer.PermitBatchTransferFrom({
                permitted: permitted,
                nonce: nonce,
                deadline: block.timestamp + 100
            });
    }
}
