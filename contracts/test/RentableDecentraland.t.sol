// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {TestLand} from "./mocks/TestLand.sol";

import {SharedSetup} from "./SharedSetup.t.sol";

import {DecentralandCollectionLibrary} from "../collections/decentraland/DecentralandCollectionLibrary.sol";
import {ICollectionLibrary} from "../collections/ICollectionLibrary.sol";
import {IRentable} from "../interfaces/IRentable.sol";

import {OLandRegistry} from "../collections/decentraland/OLandRegistry.sol";
import {ILandRegistry} from "../collections/decentraland/ILandRegistry.sol";
import {WRentable} from "../tokenization/WRentable.sol";

import {RentableTypes} from "./../RentableTypes.sol";

contract RentableDecentraland is SharedSetup {
    TestLand testLand;
    DecentralandCollectionLibrary decentralandCollectionLibrary;

    function setUp() public override {
        super.setUp();

        vm.startPrank(governance);

        testLand = new TestLand();

        orentable = new OLandRegistry(
            address(testLand),
            governance,
            address(rentable)
        );
        rentable.setORentable(address(testLand), address(orentable));

        wrentable = new WRentable(
            address(testLand),
            governance,
            address(rentable)
        );
        rentable.setWRentable(address(testLand), address(wrentable));

        decentralandCollectionLibrary = new DecentralandCollectionLibrary();
        rentable.setLibrary(
            address(testLand),
            address(decentralandCollectionLibrary)
        );

        rentable.enableProxyCall(
            address(orentable),
            ILandRegistry.setUpdateOperator.selector,
            true
        );

        vm.stopPrank();
    }

    function testFlow() public {
        /** 
        Land owned by originalOwner and with originalOperator as operator
        List for maxSeconds and pricePerSecond payed in currencyToken
        Onwer transfer to newOwner
        Renter rent for half of the time
        Transfer to newRenter
        newOwner redeem after expire*/

        address originalOwner = getNewAddress();
        uint256 tokenId = 123;
        address originalOperator = getNewAddress();
        address renter = getNewAddress();
        address newRenter = getNewAddress();
        address newOwner = getNewAddress();
        address offRentableOperator = getNewAddress();

        vm.startPrank(originalOwner);

        testLand.mint(originalOwner, tokenId);
        assertEq(testLand.ownerOf(tokenId), originalOwner);

        testLand.setUpdateOperator(tokenId, originalOperator);
        assertEq(testLand.updateOperator(tokenId), originalOperator);

        uint256 maxTimeDuration = 10;
        uint256 minTimeDuration = 0;
        uint256 pricePerSecond = 0.1 ether;

        testLand.safeTransferFrom(
            originalOwner,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    minTimeDuration: minTimeDuration,
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: 0,
                    paymentTokenAddress: address(0),
                    privateRenter: address(0)
                })
            )
        );

        assertEq(testLand.updateOperator(tokenId), originalOwner);
        vm.warp(1); //timestamp is 0 otw
        //owner must be able to change operator when rentals are not in place
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );
        assertEq(
            ILandRegistry(address(orentable)).updateOperator(tokenId),
            offRentableOperator
        );

        //non-owners cannot change rentals
        switchUser(newOwner);
        vm.expectRevert(bytes("User not allowed"));
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );

        //Transfer ownership not rented should change operator
        switchUser(originalOwner);
        orentable.safeTransferFrom(originalOwner, newOwner, tokenId);
        assertEq(testLand.updateOperator(tokenId), newOwner);

        //After changing ownership the original owner must not be allowed to change operator
        vm.expectRevert(bytes("User not allowed"));
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );

        // new owner must be able to change operator when rentals are not in place
        switchUser(newOwner);
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );
        assertEq(testLand.updateOperator(tokenId), offRentableOperator);

        //Rent
        switchUser(renter);
        depositAndApprove(renter, 1 ether, address(0), 0);

        rentable.rent{value: 1 ether}(
            address(testLand),
            tokenId,
            maxTimeDuration / 2
        );

        // Transfer newRenter
        wrentable.safeTransferFrom(renter, newRenter, tokenId);
        assertEq(testLand.updateOperator(tokenId), newRenter);

        // owner can't change operator during rental
        switchUser(newOwner);
        vm.expectRevert(bytes("Operation not allowed during rental"));
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );

        // Transfer ownership rented - must not change operator
        orentable.safeTransferFrom(newOwner, originalOwner, tokenId);
        assertEq(testLand.updateOperator(tokenId), newRenter);

        vm.warp(maxTimeDuration / 2 + 1);

        // update must be possible after lease expired even if not explicitly
        switchUser(originalOwner);
        ILandRegistry(address(orentable)).setUpdateOperator(
            tokenId,
            offRentableOperator
        );
        assertEq(
            ILandRegistry(address(orentable)).updateOperator(tokenId),
            offRentableOperator
        );

        rentable.withdraw(address(testLand), tokenId);

        assertEq(testLand.updateOperator(tokenId), address(0));
    }

    function testWTransferAfterExpireResetOperatorCorrectly() public {
        /// in the case you transfer an expired wtoken the operator
        /// was set to the recipient and not reset
        /// verify it's reset to the current otoken owner

        address originalOwner = getNewAddress();
        uint256 tokenId = 123;
        address originalOperator = getNewAddress();
        address renter = getNewAddress();
        address newRenter = getNewAddress();

        vm.startPrank(originalOwner);

        testLand.mint(originalOwner, tokenId);
        assertEq(testLand.ownerOf(tokenId), originalOwner);

        testLand.setUpdateOperator(tokenId, originalOperator);
        assertEq(testLand.updateOperator(tokenId), originalOperator);

        uint256 maxTimeDuration = 10;
        uint256 minTimeDuration = 0;
        uint256 pricePerSecond = 0.1 ether;

        testLand.safeTransferFrom(
            originalOwner,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    minTimeDuration: minTimeDuration,
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: 0,
                    paymentTokenAddress: address(0),
                    privateRenter: address(0)
                })
            )
        );

        // Rent
        switchUser(renter);
        depositAndApprove(renter, 1 ether, address(0), 0);

        rentable.rent{value: 1 ether}(
            address(testLand),
            tokenId,
            maxTimeDuration / 2
        );

        vm.warp(maxTimeDuration / 2 + 1);

        // Transfer newRenter when expired should burn the token
        // and change the operator to the current otoken owner
        wrentable.safeTransferFrom(renter, newRenter, tokenId);
        assertEq(testLand.updateOperator(tokenId), orentable.ownerOf(tokenId));
    }
}
