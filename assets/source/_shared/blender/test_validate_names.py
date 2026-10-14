"""Name rule tests for validate.mesh_name_problem (07 section 1.2). Runs without Blender:
    python3 assets/source/_shared/blender/test_validate_names.py"""
import os
import sys
import types
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
for mod in ("bpy", "bmesh", "mathutils"):           # validate imports these; the name rule needs none
    sys.modules.setdefault(mod, types.ModuleType(mod))
sys.modules["mathutils"].Vector = sys.modules["mathutils"].Matrix = object
import validate  # noqa: E402


class MeshNames(unittest.TestCase):
    def test_shell_suffix_at_the_end(self):
        for name in ("M_Species_Minnow_Juv_Shell", "M_Species_Minnow_Juv_ShellThick", "M_Species_Minnow_Juv_LOD1_Shell",
                     "M_Species_Puffer_Adult_Puffed_LOD2_ShellThick", "M_Pred_Barracuda_Shell", "M_Prey_Krill_Shell"):
            self.assertIsNone(validate.mesh_name_problem(name), name)

    def test_shell_inside_a_name(self):
        for name in ("M_Env_Shell_01", "M_Env_Shell_02"):
            self.assertIsNone(validate.mesh_name_problem(name), name)

    def test_bad_names_still_fail(self):
        self.assertIsNotNone(validate.mesh_name_problem("M_Env_Shell"))              # nothing before the suffix
        self.assertIsNotNone(validate.mesh_name_problem("M_Species_Minnow_Juv_Shell_LOD1"))   # shell not at the end
        self.assertIsNotNone(validate.mesh_name_problem("M_Species_Minnow_LOD1_Juv"))     # age after LOD


if __name__ == "__main__":
    unittest.main()
