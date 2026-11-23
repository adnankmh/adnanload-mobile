"""Guardrails for the opt-in Actions history cleanup workflow."""
from pathlib import Path
import unittest

WORKFLOW = (Path(__file__).resolve().parents[1] / ".github/workflows/prune-actions-history.yml")


class PruneActionsWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORKFLOW.read_text(encoding="utf-8")

    def test_only_main_path_push_or_manual_dispatch(self):
        self.assertIn("workflow_dispatch:", self.source)
        self.assertIn("branches: [main]", self.source)
        self.assertIn("prune-actions-history.yml", self.source)
        self.assertNotIn("pull_request:", self.source)

    def test_action_write_permission_is_explicit_and_scoped(self):
        self.assertIn("  actions: write", self.source)
        self.assertIn("  contents: read", self.source)
        self.assertIn("github.rest.actions.deleteWorkflowRun", self.source)
        self.assertNotIn("deleteRepo", self.source)

    def test_latest_five_and_active_runs_are_protected(self):
        self.assertIn("ordered.slice(0, 5)", self.source)
        self.assertIn("protectedIds.add(context.runId)", self.source)
        self.assertIn("run.status === 'completed'", self.source)
        self.assertIn("!protectedIds.has(run.id)", self.source)

    def test_failure_is_not_reported_as_success(self):
        self.assertIn("failures.push(", self.source)
        self.assertIn("core.setFailed(", self.source)
        self.assertIn("await github.rest.actions.deleteWorkflowRun", self.source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
