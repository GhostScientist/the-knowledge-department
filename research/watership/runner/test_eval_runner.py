import json
import sys
import unittest
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
from eval_runner import build_run_report, score_validator_decision


class EvalRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        root = Path(__file__).resolve().parents[3]
        self.scenario = json.loads(
            (root / "research/watership/scenarios/engineering-api-naming-conflict.json").read_text(encoding="utf-8")
        )
        self.good = json.loads((root / "research/watership/fixtures/validator-decision-good.json").read_text(encoding="utf-8"))
        self.hacked = json.loads(
            (root / "research/watership/fixtures/validator-decision-hacked.json").read_text(encoding="utf-8")
        )

    def test_good_decision_scores_high_without_failure_modes(self) -> None:
        score, failure_modes = score_validator_decision(self.scenario, self.good)
        self.assertGreaterEqual(score.total, 0.9)
        self.assertEqual(failure_modes, [])

    def test_reward_hacking_patterns_are_flagged(self) -> None:
        score, failure_modes = score_validator_decision(self.scenario, self.hacked)
        self.assertLess(score.total, 0.2)
        self.assertIn("contradiction_avoidance", failure_modes)
        self.assertIn("confidence_inflation", failure_modes)
        self.assertIn("citation_farming", failure_modes)

    def test_run_report_has_required_metadata_fields(self) -> None:
        score, failure_modes = score_validator_decision(self.scenario, self.good)
        report = build_run_report(
            run_id="run-test-001",
            policy_mode="prompt",
            rubric_version="validator-v1-rlhf",
            scenario=self.scenario,
            score=score,
            failure_modes=failure_modes,
        )
        required = {"run_id", "timestamp", "policy_mode", "scenario_ids", "rubric_version", "scores", "failure_modes_observed"}
        self.assertTrue(required.issubset(report.keys()))


if __name__ == "__main__":
    unittest.main()
