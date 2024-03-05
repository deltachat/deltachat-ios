cd deltachat-ios/libraries/deltachat-core-rust
cargo clean
cd -

rm -rf deltachat-ios/libraries/deltachat-core-rust/target
rm deltachat-ios/libraries/libdeltachat.a

echo "now, in Xcode, run 'Product / Clean Build Folder'"
