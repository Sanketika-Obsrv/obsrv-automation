"""The denorm check's SELECT has to contain the column it compares on.

The check samples a few joined rows and asserts the joined userName is the one
the master holds for that actor.id. It built the SELECT from the first 8 joined
columns and then read userName out of the result -- but the columns arrive
sorted, and `user.userName` sorts 10th of 10. It was never fetched, r.get()
returned None for every row, and a correct join reported

    105/105 rows joined (100.0%) on 10 columns, values DO NOT match the master

for a datasource whose user.id matched actor_id on every sampled row.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))

from benchmark.agents.validation import (                              # noqa: E402
    _denorm_name_col, _denorm_resolved_nothing, _denorm_select_cols)

# The real column list from the failing run, in the order Druid returns it.
JOINED = ["user.age", "user.city", "user.department", "user.device",
          "user.gender", "user.id", "user.organization", "user.state",
          "user.subscription", "user.userName"]


class DenormSelect(unittest.TestCase):
    def test_name_column_is_selected(self):
        """The regression: userName sorts past the truncation point."""
        self.assertIn("user.userName", _denorm_select_cols(JOINED))

    def test_selection_is_still_bounded(self):
        """Truncation exists to keep the sample readable -- keep it."""
        wide = ["user.col%02d" % i for i in range(40)] + ["user.userName"]
        cols = _denorm_select_cols(wide)
        self.assertLessEqual(len(cols), 9)
        self.assertIn("user.userName", cols)

    def test_no_duplicates_when_name_already_in_range(self):
        early = ["user.age", "user.userName"]
        self.assertEqual(_denorm_select_cols(early), early)

    def test_name_col_detection(self):
        self.assertEqual(_denorm_name_col(JOINED), "user.userName")
        self.assertIsNone(_denorm_name_col(["user.age", "user.city"]))


class SelfHealTrigger(unittest.TestCase):
    """The rebuild is for an empty join, not for any failed denorm check."""

    def test_no_columns_is_worth_healing(self):
        self.assertTrue(_denorm_resolved_nothing({"evidence": {"columns": []}}))

    def test_columns_but_no_rows_is_worth_healing(self):
        self.assertTrue(_denorm_resolved_nothing(
            {"evidence": {"columns": JOINED, "rows_joined": 0}}))

    def test_populated_join_is_never_healed(self):
        """The regression: a 105/105 join that the check called mismatched."""
        self.assertFalse(_denorm_resolved_nothing(
            {"evidence": {"columns": JOINED, "rows_joined": 105,
                          "values_match_master": False}}))


if __name__ == "__main__":
    unittest.main(verbosity=2)
