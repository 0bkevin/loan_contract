//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

/**
asegurarse de que el colateral sea mayor al prestado
asegurarse de que el lender gane algo de interes 
tener un aumento de interes por cada dia o semana o mes

tener la oportunidad de pedir mas dinero prestado

tener la oportunidad de pagar el dinero de apoquito
 */

contract Loan {
    //Data structure for the terms  of loan
    struct Terms {
        uint256 loanDaiAmount;
        uint256 deeDaiAmount;
        uint256 ethCollateralAmount; /**Is expected to be more value 
        than the loan, so the lender doesnt loose any money
        */
        uint256 timestamp;
    }

    Terms public terms;

    /**
    @dev  The loan can be in 5 states. Created, Funded,
    Taken, Repayed, Liquidated
    
    In the later two states the contract will be destroyed. For that we dont defined here
    */
    enum LoanState {Created, Funded, Token}

    LoanState public state;

    modifier onlyInState(LoanState _expectedState) {
        require(state == _expectedState, "Not allowed to call this function in this state");
        _;
    }

    address payable public borrower;
    address payable public lender;
    address public daiAddress;

    constructor(Terms memory _terms, address _daiAddress) {
        terms = _terms;
        daiAddress = _daiAddress;
        lender = msg.sender;
        state = LoanState.Created;
    }

    /**
    @notice Transfer DAI from the lender 'msg.sender' to the contract
    , those founds are going to be transfer to the borrower later

    REQUIREMENTS:
    The lender needs to allows the contract to do this transfer
     */
    function fundLoan() public onlyInState(LoanState.Created) {

        state = LoanState.Funded;
        DAI(daiAddress).transferFrom(
            msg.sender,
            address(this),
            terms.loanDaiAmount
        );

    }
    /**
    @notice takes the loans and accept the loans terms 

    @dev collateral should be transfered when calling this function
    
    REQUIREMENTS:
    The exact amount of collateral (eth) must be transferd.

    */
    function takeLoanAndAcceptTerms ()
    public
    payable
    onlyInState(LoanState.Funded)
    {
        require (
            msg.value == terms.ethCollateralAmount, 
            "Invalid collateral amount"
        );
        borrower = msg.sender;
        state = LoanState.Taken;
        DAI(daiAddress).transfer(borrower, terms.loanDaiAmount);
    }

    /**
    @notice repays the loan, can be repayed early with no fees. 
    @dev at the end the collateral would be send to the borrower and this contract would be destroyed.
    
        REQUIREMENTS:
       - Borrower should allows this contract to pull the tokens before calling this function
        - Only the borrower can repay the loan
     */
    function repay() public onlyInState(LoanState.Taken) {
        require(msg.sender == borrower, 
        "Only the borrower can repay the loan"
        );

        DAI(daiAddress).transferFrom(
            borrower, 
            lender,
            terms.loanDaiAmount + terms.feeDaiAmount
        );
        
        selfdestruct(borrower);
    }

    /**
    @notice allows the lender to liquidity the loan, this in case that the loan is not repayed on time.
        
    it would be transfer to whole collateral to the lender. 

    @dev 
    REQUIREMENTS

    -Only the lender is allowed to call this 
    - The due time of the loan have to be arrived.


     */
    function liquidate() public onlyInState(LoanState.Taken) {
        require(msg.sender == lender, 
        "Only the lender can lquidity the loan"
        );

        require(block.timestamp >= terms.timestamp,
        "Cannot liquidate before the loan is due"
        );
    }

    selfdestruct(lender);

}