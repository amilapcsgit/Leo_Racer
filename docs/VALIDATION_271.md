# Leo Racer 2.7.1 validation

The 2.7.1 candidate retains the gameplay and content of 2.7.0 and adds a
credits screen and licensing notices. Historical 2.7.0 measurements and
limitations are documented in `VALIDATION_270.md`.

For this candidate, the source input test passed 35 checks and the source
Ultra core test passed 54 checks. The exported core test passed, including
with no installed .NET SDK in its test environment. The source UI suite
passed, including the Credits dialog at 1280×720, 1920×1080, 2560×1440 and
2560×1080; the 1280×720 capture was visually inspected. The fresh installer,
upgrade preservation, uninstall preservation and portable extraction tests
passed. License and author/dedication files are present in the package.

The UI run logged leaked texture handles at shutdown. One exported-core run
also logged ObjectDB/resource shutdown warnings despite passing; another
exported-core run completed without them. Physical controller handling was not
retested, and the earlier performance limitations still apply. See the
evidence archive for raw logs and machine-readable results.
