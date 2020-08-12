import React, {Component, useState} from 'react';
import {OrchidAPI} from "../api/orchid-api";
import {keikiToOxtString} from "../api/orchid-eth";
import {LockStatus} from "./LockStatus";
import {errorClass, formatCurrency, Visibility} from "../util/util";
import './Info.css'
import {Button, Col, Container, Row} from "react-bootstrap";
import {Subscription} from "rxjs";
import {AccountQRCode} from "./AccountQRCode";
import {S} from "../i18n/S";
import {Orchid} from "../api/orchid";
import {AccountRecommendation} from "./MarketConditionsPanel";

const BigInt = require("big-integer"); // Mobile Safari requires polyfill

export class Info extends Component<any, any> {
  state = {
    signerAddress: "",
    signerConfigString: undefined,
    walletAddress: "",
    ethBalance: "",
    ethBalanceError: true,
    oxtBalance: "",
    oxtBalanceError: true,
    potBalance: "",
    potEscrow: "",
    accountRecommendationBalanceMin: null,
    accountRecommendationBalance: null,
    accountRecommendationDepositMin: null,
    accountRecommendationDeposit: null,
  };
  subscriptions: Subscription [] = [];
  walletAddressInput = React.createRef<HTMLInputElement>();
  signerAddressInput = React.createRef<HTMLInputElement>();

  componentDidMount(): void {
    let api = OrchidAPI.shared();

    this.subscriptions.push(
      api.signer.subscribe(signer => {
        this.setState({
          signerAddress: signer != null ? signer.address : "",
          signerConfigString: signer != null ? signer.toConfigString() : undefined
        });
      }));

    this.subscriptions.push(
      api.wallet_wait.subscribe(wallet => {
        this.setState({
          walletAddress: wallet.address,
          ethBalance: keikiToOxtString(wallet.ethBalance, 4),
          ethBalanceError: wallet.ethBalance <= BigInt(0),
          oxtBalance: keikiToOxtString(wallet.oxtBalance, 4),
          oxtBalanceError: wallet.oxtBalance <= BigInt(0),
        });
      }));

    this.subscriptions.push(
      api.lotteryPot_wait.subscribe(pot => {
        this.setState({
          potBalance: keikiToOxtString(pot.balance, 4),
          potEscrow: keikiToOxtString(pot.escrow, 4)
        });
      }));

    (async () => {
      let minViableAccountRecommendation = await Orchid.minViableAccountComposition();
      let accountRecommendation = await Orchid.recommendedAccountComposition();
      this.setState({
        accountRecommendationBalanceMin: minViableAccountRecommendation.balance.value.toFixedLocalized(2),
        accountRecommendationDepositMin: minViableAccountRecommendation.deposit.value.toFixedLocalized(2),
        accountRecommendationBalance: accountRecommendation.balance.value.toFixedLocalized(2),
        accountRecommendationDeposit: accountRecommendation.deposit.value.toFixedLocalized(2)
      });
    })();
  }

  componentWillUnmount(): void {
    this.subscriptions.forEach(sub => {
      sub.unsubscribe()
    })
  }

  copyWalletAddress() {
    if (this.walletAddressInput.current == null) {
      return;
    }
    this.walletAddressInput.current.select();
    document.execCommand('copy');
  };

  copySignerAddress() {
    if (this.signerAddressInput.current == null) {
      return;
    }
    this.signerAddressInput.current.select();
    document.execCommand('copy');
  };

  render() {
    return (
      <Container className="Balances form-style">
        <label className="title">{S.info}</label>

        {/*wallet address*/}
        <label style={{fontWeight: "bold"}}>{S.walletAddress}</label>
        <Row noGutters={true}>
          <Col style={{flexGrow: 10}}>
            <input type="text"
                   style={{textOverflow: "ellipsis"}}
                   ref={this.walletAddressInput}
                   value={this.state.walletAddress} placeholder={S.address} readOnly/>
          </Col>
          <Col style={{marginLeft: '8px'}}>
            <Button variant="light" onClick={this.copyWalletAddress.bind(this)}>{S.copy}</Button>
          </Col>
        </Row>

        {/*wallet balance*/}
        <div className="form-row col-1-1">
          <div className="form-row col-1-2">
            <label className="form-row-label">ETH</label>
            <span className={errorClass(this.state.ethBalanceError)}> * </span>
            <input className="form-row-field" type="text"
                   value={this.state.ethBalance}
                   readOnly/>
          </div>
          <div className="form-row col-1-2">
            <label className="form-row-label">OXT</label>
            <span className={errorClass(this.state.oxtBalanceError)}> * </span>
            <input className="form-row-field" type="text"
                   value={this.state.oxtBalance}
                   readOnly/>
          </div>
        </div>

        {/*signer address*/}
        <label style={{fontWeight: "bold", marginTop: "16px"}}>{S.signerAddress}</label>
        <Row noGutters={true}>
          <Col style={{flexGrow: 10}}>
            <input type="text"
                   style={{textOverflow: "ellipsis"}}
                   ref={this.signerAddressInput}
                   value={this.state.signerAddress} placeholder={S.address} readOnly/>
          </Col>
          <Col style={{marginLeft: '8px'}}>
            <Button variant="light" onClick={this.copySignerAddress.bind(this)}>{S.copy}</Button>
          </Col>
        </Row>

        {/*account QR Code*/}
        <Visibility visible={this.state.signerConfigString !== undefined}>
          <AccountQRCode data={this.state.signerConfigString}/>
        </Visibility>

        {/*pot balance and escrow*/}
        <label style={{fontWeight: "bold", marginTop: "16px"}}>{S.lotteryPot}</label>
        <div className="form-row col-1-1">
          <div className="form-row col-1-2">
            <label className="form-row-label">{"My Balance"}</label>
            <input className="form-row-field"
                   value={this.state.potBalance}
                   type="text" readOnly/>
          </div>
          <div className="form-row col-1-2">
            <label className="form-row-label">{"My Deposit"}</label>
            <input className="form-row-field"
                   value={this.state.potEscrow}
                   type="text" readOnly/>
          </div>
        </div>

        {/* market stats */}
        <label style={{fontWeight: "bold", marginTop: "16px"}}>{"Market Stats"}</label>
        <div className="form-row col-1-1">
          <div className="form-row col-1-2">
            <label className="form-row-label">{"Min Viable Balance"}</label>
            <input className="form-row-field"
                   value={this.state.accountRecommendationBalanceMin || "..."}
                   type="text" readOnly/>
          </div>
          <div className="form-row col-1-2">
            <label className="form-row-label">{"Min Viable Deposit"}</label>
            <input className="form-row-field"
                   value={this.state.accountRecommendationDepositMin || "..."}
                   type="text" readOnly/>
          </div>
        </div>
        <div className="form-row col-1-1">
          <div className="form-row col-1-2">
            <label className="form-row-label">{"Recommended Balance"}</label>
            <input className="form-row-field"
                   value={this.state.accountRecommendationBalance || "..."}
                   type="text" readOnly/>
          </div>
          <div className="form-row col-1-2">
            <label className="form-row-label">{"Recommended Deposit"}</label>
            <input className="form-row-field"
                   value={this.state.accountRecommendationDeposit || "..."}
                   type="text" readOnly/>
          </div>
          <label className="form-row-label" style={{fontStyle: "italic"}}>
            Recommendation based on: <b>{Orchid.recommendationEfficiency * 100}% efficiency</b> and <b>{Orchid.recommendationBalanceFaceValues.toFixedLocalized(1)} Face Value</b> balance.
          </label>
        </div>

        {/*pot lock status*/}
        <div style={{marginTop: "16px"}}/>
        <LockStatus/>

      </Container>
    );
  }
}

