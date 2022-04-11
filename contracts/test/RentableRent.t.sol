// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {SharedSetup} from "./SharedSetup.t.sol";

import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";
import {RentableTypes} from "./../RentableTypes.sol";

contract RentableRent is SharedSetup {
    address paymentTokenAddress = address(0);
    uint256 paymentTokenId = 0;
    uint256 tokenId = 123;

    function getBalance(
        address user,
        address paymentToken,
        uint256 _paymentTokenId
    ) public view returns (uint256) {
        if (paymentToken == address(weth)) {
            return weth.balanceOf(user);
        } else if (paymentToken == address(dummy1155)) {
            return dummy1155.balanceOf(user, _paymentTokenId);
        } else {
            return user.balance;
        }
    }

    function testRent() public payable {
        vm.startPrank(user);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = vm.addr(5);
        address privateRenter = address(0);
        prepareTestDeposit(tokenId);
        //1tx
        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: paymentTokenId,
                    paymentTokenAddress: paymentTokenAddress,
                    privateRenter: privateRenter
                })
            )
        );

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        // Test event emitted
        vm.expectEmit(true, true, true, true);

        emit Rent(
            user,
            renter,
            address(testNFT),
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            block.timestamp + rentalDuration
        );

        vm.stopPrank();
        vm.startPrank(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        uint256 preBalanceUser = getBalance(
            user,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 preBalanceFeeCollector = getBalance(
            feeCollector,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 preBalanceRenter = getBalance(
            renter,
            paymentTokenAddress,
            paymentTokenId
        );

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        vm.stopPrank();
        vm.startPrank(user);

        uint256 postBalanceUser = getBalance(
            user,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 postBalanceFeeCollector = getBalance(
            feeCollector,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 postBalanceRenter = getBalance(
            renter,
            paymentTokenAddress,
            paymentTokenId
        );

        uint256 rentPayed = preBalanceRenter - postBalanceRenter;

        assertEq(
            rentable.expiresAt(address(testNFT), tokenId),
            block.timestamp + rentalDuration
        );

        uint256 totalFeesToPay = (rentPayed * rentable.getFee()) / 10_000;

        assertEq(
            postBalanceFeeCollector - preBalanceFeeCollector,
            totalFeesToPay
        );

        uint256 renteePayout = preBalanceRenter - postBalanceRenter;

        assertEq(postBalanceUser - preBalanceUser, renteePayout);

        assertEq(wrentable.ownerOf(tokenId), renter);

        vm.warp(block.timestamp + rentalDuration + 1);

        assertEq(wrentable.ownerOf(tokenId), address(0));

        // Test event emitted
        vm.expectEmit(true, true, true, true);
        emit RentEnds(address(testNFT), tokenId);

        rentable.expireRental(address(testNFT), tokenId);

        vm.stopPrank();
    }

    function testRentPrivate() public payable {
        vm.startPrank(user);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = vm.addr(5);
        address privateRenter = renter;

        prepareTestDeposit(tokenId);

        //1tx
        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: paymentTokenId,
                    paymentTokenAddress: paymentTokenAddress,
                    privateRenter: privateRenter
                })
            )
        );

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        vm.stopPrank();
        vm.startPrank(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        uint256 preBalanceUser = getBalance(
            user,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 preBalanceFeeCollector = getBalance(
            feeCollector,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 preBalanceRenter = getBalance(
            renter,
            paymentTokenAddress,
            paymentTokenId
        );

        vm.stopPrank();
        vm.startPrank(vm.addr(8));
        depositAndApprove(
            vm.addr(8),
            value,
            paymentTokenAddress,
            paymentTokenId
        );
        vm.expectRevert(bytes("Rental reserved for another user"));
        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        vm.stopPrank();
        vm.startPrank(renter);

        // Test event emitted
        vm.expectEmit(true, true, true, true);

        emit Rent(
            user,
            renter,
            address(testNFT),
            tokenId,
            paymentTokenAddress,
            paymentTokenId,
            block.timestamp + rentalDuration
        );

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        vm.stopPrank();
        vm.startPrank(user);

        uint256 postBalanceUser = getBalance(
            user,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 postBalanceFeeCollector = getBalance(
            feeCollector,
            paymentTokenAddress,
            paymentTokenId
        );
        uint256 postBalanceRenter = getBalance(
            renter,
            paymentTokenAddress,
            paymentTokenId
        );

        uint256 rentPayed = preBalanceRenter - postBalanceRenter;

        assertEq(
            rentable.expiresAt(address(testNFT), tokenId),
            block.timestamp + rentalDuration
        );

        uint256 totalFeesToPay = (rentPayed * rentable.getFee()) / 10_000;

        assertEq(
            postBalanceFeeCollector - preBalanceFeeCollector,
            totalFeesToPay
        );

        uint256 renteePayout = preBalanceRenter - postBalanceRenter;

        assertEq(postBalanceUser - preBalanceUser, renteePayout);

        assertEq(wrentable.ownerOf(tokenId), renter);

        vm.warp(block.timestamp + rentalDuration + 1);

        assertEq(wrentable.ownerOf(tokenId), address(0));

        // Test event emitted
        vm.expectEmit(true, true, true, true);
        emit RentEnds(address(testNFT), tokenId);

        rentable.expireRental(address(testNFT), tokenId);

        vm.stopPrank();
    }

    function testCannotWithdrawOnRent() public payable {
        vm.startPrank(user);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = vm.addr(5);
        address privateRenter = address(0);

        prepareTestDeposit(tokenId);

        //1tx
        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: paymentTokenId,
                    paymentTokenAddress: paymentTokenAddress,
                    privateRenter: privateRenter
                })
            )
        );

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        vm.stopPrank();
        vm.startPrank(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        vm.stopPrank();
        vm.startPrank(user);

        vm.expectRevert(bytes("Current rent still pending"));
        rentable.withdraw(address(testNFT), tokenId);

        vm.warp(block.timestamp + rentalDuration + 1);

        rentable.withdraw(address(testNFT), tokenId);

        tokenId++;

        vm.stopPrank();
    }

    function testTransferWToken() public payable {
        vm.startPrank(user);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = vm.addr(5);
        address privateRenter = address(0);

        prepareTestDeposit(tokenId);

        //1tx
        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: paymentTokenId,
                    paymentTokenAddress: paymentTokenAddress,
                    privateRenter: privateRenter
                })
            )
        );

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        vm.stopPrank();
        vm.startPrank(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        bytes memory expectedData = abi.encodeWithSelector(
            ICollectionLibrary.postWTokenTransfer.selector,
            address(testNFT),
            tokenId,
            renter,
            vm.addr(9)
        );
        vm.expectCall(address(dummyLib), expectedData);

        wrentable.transferFrom(renter, vm.addr(9), tokenId);

        assertEq(wrentable.ownerOf(tokenId), vm.addr(9));

        vm.stopPrank();
        vm.startPrank(user);

        vm.stopPrank();
    }

    function testTransferOToken() public payable {
        vm.startPrank(user);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = vm.addr(5);
        address privateRenter = address(0);
        prepareTestDeposit(tokenId);

        //1tx
        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: paymentTokenId,
                    paymentTokenAddress: paymentTokenAddress,
                    privateRenter: privateRenter
                })
            )
        );

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        vm.stopPrank();
        vm.startPrank(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        vm.stopPrank();
        vm.startPrank(user);

        bytes memory expectedData = abi.encodeWithSelector(
            ICollectionLibrary.postOTokenTransfer.selector,
            address(testNFT),
            tokenId,
            user,
            vm.addr(9),
            true
        );
        vm.expectCall(address(dummyLib), expectedData);

        orentable.transferFrom(user, vm.addr(9), tokenId);

        assertEq(orentable.ownerOf(tokenId), vm.addr(9));

        vm.stopPrank();
    }

    function testRentAfterExpire() public payable {
        vm.startPrank(user);

        uint256 maxTimeDuration = 1000;
        uint256 pricePerSecond = 0.001 ether;

        address renter = vm.addr(5);
        address privateRenter = address(0);

        prepareTestDeposit(tokenId);

        //1tx
        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: paymentTokenId,
                    paymentTokenAddress: paymentTokenAddress,
                    privateRenter: privateRenter
                })
            )
        );

        uint256 rentalDuration = 80;
        uint256 value = 0.08 ether;

        vm.stopPrank();
        vm.startPrank(renter);
        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        vm.warp(block.timestamp + rentalDuration + 1);

        depositAndApprove(renter, value, paymentTokenAddress, paymentTokenId);

        rentable.rent{value: paymentTokenAddress == address(0) ? value : 0}(
            address(testNFT),
            tokenId,
            rentalDuration
        );

        vm.stopPrank();
        vm.startPrank(user);

        vm.stopPrank();
    }
}
