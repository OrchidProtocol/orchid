import {AccountRecommendation, MarketConditions} from "../components/MarketConditionsPanel";

export class Orchid {
  static recommendationEfficiency: number = 0.5; // 50%
  static recommendationBalanceFaceValues: number = 3.0;

  static recommendedAccountComposition(): Promise<AccountRecommendation> {
    return MarketConditions.recommendation(this.recommendationEfficiency, this.recommendationBalanceFaceValues);
  }

  static minViableEfficiency: number = 0.01; // 1%,
  static minViableBalanceFaceValues: number = 1;

  static minViableAccountComposition(): Promise<AccountRecommendation> {
    return MarketConditions.recommendation(this.minViableEfficiency, this.minViableBalanceFaceValues);
  }
}
