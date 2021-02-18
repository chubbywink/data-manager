// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "@yield-protocol/utils/contracts/token/IERC20.sol";
import "./interfaces/IFYToken.sol";
import "./interfaces/IJoin.sol";
import "./interfaces/IVat.sol";
// import "./interfaces/IOracle.sol";
import "./libraries/DataTypes.sol";


contract FrobProxy {

    IVat public vat;

    mapping (bytes6 => IJoin)                public ilkJoins;           // Join contracts available to manage collateral. 12 bytes still free.

    constructor (IVat vat_) {
        vat = vat_;
    }

    /// @dev Add a new Join for an Ilk. There can be only onw Join per Ilk. Until a Join is added, no tokens of that Ilk can be posted or withdrawn.
    function addIlkJoin(bytes6 ilkId, IJoin join)
        external
        /*auth*/
        // ilkExists(ilkId)                                              // 1 SLOAD
    {
        ilkJoins[ilkId] = join;                                       // 1 SSTORE
        emit IlkJoinAdded(ilkId, address(join));
    }

    // Add collateral and borrow from vault, pull ilks from and push borrowed asset to user
    // Or, repay to vault and remove collateral, pull borrowed asset from and push ilks to user
    // Doesn't check inputs, or collateralization level. Do that in public functions.
    // TODO: Extend to allow other accounts in `join`
    function frob(bytes12 vaultId, int128 ink, int128 art)
        internal returns (DataTypes.Balances memory _balances)
    {
        DataTypes.Vault memory _vault = vat.vaults(vaultId);                // 1 CALL + 1 SLOAD
        require (_vault.owner == msg.sender, "Only vault owner");

        if (ink != 0) {
            int128 inkJoined = ilkJoins[_vault.ilkId].join(_vault.owner, ink); // Cost of `join` call. `join` with a negative value means `exit`.. Consider whether it's possible to achieve this without an external call, so that `Vat` doesn't depend on the `Join` interface.
        }

        DataTypes.Balances memory _balances = vat._frob(vaultId, ink, art);                                   // Cost of `vat.frob` call.

        if (art != 0) {
            DataTypes.Series memory _series = vat.series(_vault.seriesId);      // 1 CALL + 1 SLOAD
            if (art > 0) {
                require(block.timestamp <= _series.maturity, "Mature");
                IFYToken(_series.fyToken).mint(msg.sender, art);        // 1 CALL(40) + fyToken.mint. Consider whether it's possible to achieve this without an external call, so that `Vat` doesn't depend on the `FYDai` interface.
            } else {
                IFYToken(_series.fyToken).burn(msg.sender, art);        // 1 CALL(40) + fyToken.burn. Consider whether it's possible to achieve this without an external call, so that `Vat` doesn't depend on the `FYDai` interface.
            }
        }

        return _balances;
    }
}