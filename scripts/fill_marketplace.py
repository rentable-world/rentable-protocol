import eth_abi
import random

from brownie import (
    accounts,
    TestNFT,
)


def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i : i + n]


def listOnMarket(
    user,
    token,
    rentable,
    tokenId,
    maxTimeDuration,
    pricePerSecond,
    paymentTokenId,
    paymentTokenAddress,
    privateRenter,
):
    data = eth_abi.encode_abi(
        [
            "uint256",
            "uint256",
            "uint256",
            "address",
            "address",
        ],
        (
            maxTimeDuration,
            pricePerSecond,
            paymentTokenId,
            paymentTokenAddress,
            privateRenter,
        ),
    ).hex()
    token.safeTransferFrom(user, rentable, tokenId, data, {"from": user})


def main():
    dev = accounts.load("rentable-deployer")
    testNFT = TestNFT.at("0x4aB8a4e7B2fAbbDcaA8398A3829718DeAC831196")
    rentable = "0xFec9DfE525ec5a2214AD5a223AA6E484953E2D70"

    startId = 2
    endId = 243

    day = 24 * 60 * 60
    maxTimeDurationLow = 3 * day
    maxTimeDurationHigh = 15 * day
    timeStep = day / 2

    eth = 1e18
    minPrice = int(0.1 * eth / day)
    maxPrice = int(5 * eth / day)
    priceStep = int(0.2 * eth / day)

    for c in range(startId, endId):
        print(c)
        maxTimeDuration = random.randrange(
            maxTimeDurationLow, maxTimeDurationHigh, timeStep
        )
        pricePerSecond = random.randrange(minPrice, maxPrice, priceStep)
        paymentTokenId = 0
        paymentTokenAddress = "0x0000000000000000000000000000000000000000"
        privateRenter = "0x0000000000000000000000000000000000000000"
        listOnMarket(
            dev,
            testNFT,
            rentable,
            c,
            maxTimeDuration,
            pricePerSecond,
            paymentTokenId,
            paymentTokenAddress,
            privateRenter,
        )