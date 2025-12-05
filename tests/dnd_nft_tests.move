#[test_only]
module dnd_nft::dnd_content_tests {
    use sui::test_scenario;
    use sui::clock;
    use std::string;
    use oclp::oclp_package::{Self, OCLPPackage};
    use dnd_nft::dnd_content::{Self, DnDContent};

    // ═══════════════════════════════════════════════════════════════════════
    // Test Constants
    // ═══════════════════════════════════════════════════════════════════════

    const TEST_SENDER: address = @0xCAFE;

    // Valid 32-byte test hashes
    const TEST_MERKLE_ROOT: vector<u8> = vector[
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20
    ];

    const TEST_MANIFEST_HASH: vector<u8> = vector[
        0x20, 0x1f, 0x1e, 0x1d, 0x1c, 0x1b, 0x1a, 0x19,
        0x18, 0x17, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11,
        0x10, 0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09,
        0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01
    ];

    // ═══════════════════════════════════════════════════════════════════════
    // Helper Functions
    // ═══════════════════════════════════════════════════════════════════════

    fun create_test_clock(scenario: &mut test_scenario::Scenario): clock::Clock {
        let ctx = test_scenario::ctx(scenario);
        clock::create_for_testing(ctx)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Mint Tests
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fun test_mint_creates_both_objects() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint via domain
        {
            let mut clock = create_test_clock(&mut scenario);
            clock::set_for_testing(&mut clock, 1000);
            
            let dnd_content = dnd_content::mint(
                string::utf8(b"Elder Void Wurm"),
                61,
                TEST_MERKLE_ROOT,
                b"package_blob_id",
                string::utf8(b"1.4"),
                61,
                TEST_MANIFEST_HASH,
                b"manifest_blob_id",
                option::none(),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            // Transfer DnDContent to sender
            sui::transfer::public_transfer(dnd_content, TEST_SENDER);
            clock::destroy_for_testing(clock);
        };
        
        // Second transaction: verify both objects exist for sender
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            // Should have DnDContent
            assert!(test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 0);
            
            // Should also have OCLPPackage (transferred independently)
            assert!(test_scenario::has_most_recent_for_sender<OCLPPackage>(&scenario), 1);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_mint_provenance_id_matches() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint
        {
            let clock = create_test_clock(&mut scenario);
            
            let dnd_content = dnd_content::mint(
                string::utf8(b"Test Monster"),
                61,
                TEST_MERKLE_ROOT,
                b"package_blob_id",
                string::utf8(b"1.4"),
                61,
                TEST_MANIFEST_HASH,
                b"manifest_blob_id",
                option::none(),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            sui::transfer::public_transfer(dnd_content, TEST_SENDER);
            clock::destroy_for_testing(clock);
        };
        
        // Second transaction: verify provenance_id matches OCLPPackage id
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            let oclp_package = test_scenario::take_from_sender<OCLPPackage>(&scenario);
            
            // The DnDContent's provenance_id should match the OCLPPackage's id
            let provenance_id = dnd_content::get_provenance_id(&dnd_content);
            let package_id = oclp_package::get_id(&oclp_package);
            
            assert!(provenance_id == package_id, 0);
            
            test_scenario::return_to_sender(&scenario, dnd_content);
            test_scenario::return_to_sender(&scenario, oclp_package);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_mint_to_sender() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint to sender
        {
            let clock = create_test_clock(&mut scenario);
            
            dnd_content::mint_to_sender(
                string::utf8(b"Direct Mint Monster"),
                61,
                TEST_MERKLE_ROOT,
                b"package_blob_id",
                string::utf8(b"1.4"),
                61,
                TEST_MANIFEST_HASH,
                b"manifest_blob_id",
                option::none(),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
        };
        
        // Second transaction: verify sender owns both
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            let oclp_package = test_scenario::take_from_sender<OCLPPackage>(&scenario);
            
            // Verify linkage
            assert!(dnd_content::get_provenance_id(&dnd_content) == oclp_package::get_id(&oclp_package), 0);
            
            // Verify package data is correct
            assert!(oclp_package::get_package_name(&oclp_package) == string::utf8(b"Direct Mint Monster"), 1);
            
            test_scenario::return_to_sender(&scenario, dnd_content);
            test_scenario::return_to_sender(&scenario, oclp_package);
        };
        
        test_scenario::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Delete Tests
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fun test_delete_wrapper_only() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint
        {
            let clock = create_test_clock(&mut scenario);
            
            dnd_content::mint_to_sender(
                string::utf8(b"Monster to Delete"),
                61,
                TEST_MERKLE_ROOT,
                b"package_blob_id",
                string::utf8(b"1.4"),
                61,
                TEST_MANIFEST_HASH,
                b"manifest_blob_id",
                option::none(),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
        };
        
        // Second transaction: delete only the wrapper
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            dnd_content::delete(dnd_content);
        };
        
        // Third transaction: verify wrapper gone but OCLPPackage remains
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            // DnDContent should be gone
            assert!(!test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 0);
            
            // OCLPPackage should still exist
            assert!(test_scenario::has_most_recent_for_sender<OCLPPackage>(&scenario), 1);
            
            // Clean up the remaining package
            let oclp_package = test_scenario::take_from_sender<OCLPPackage>(&scenario);
            oclp_package::delete(oclp_package);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_delete_with_provenance() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint
        {
            let clock = create_test_clock(&mut scenario);
            
            dnd_content::mint_to_sender(
                string::utf8(b"Monster to Fully Delete"),
                61,
                TEST_MERKLE_ROOT,
                b"package_blob_id",
                string::utf8(b"1.4"),
                61,
                TEST_MANIFEST_HASH,
                b"manifest_blob_id",
                option::none(),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
        };
        
        // Second transaction: delete both together
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            let oclp_package = test_scenario::take_from_sender<OCLPPackage>(&scenario);
            
            dnd_content::delete_with_provenance(dnd_content, oclp_package);
        };
        
        // Third transaction: verify both are gone
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            assert!(!test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 0);
            assert!(!test_scenario::has_most_recent_for_sender<OCLPPackage>(&scenario), 1);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = dnd_content::E_PROVENANCE_MISMATCH)]
    fun test_delete_with_wrong_provenance_fails() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint two separate packages
        {
            let clock = create_test_clock(&mut scenario);
            
            // Mint first
            dnd_content::mint_to_sender(
                string::utf8(b"Monster One"),
                61,
                TEST_MERKLE_ROOT,
                b"package_blob_id_1",
                string::utf8(b"1.4"),
                61,
                TEST_MANIFEST_HASH,
                b"manifest_blob_id_1",
                option::none(),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
        };
        
        // Second transaction: mint another
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let clock = create_test_clock(&mut scenario);
            
            dnd_content::mint_to_sender(
                string::utf8(b"Monster Two"),
                61,
                TEST_MERKLE_ROOT,
                b"package_blob_id_2",
                string::utf8(b"1.4"),
                61,
                TEST_MANIFEST_HASH,
                b"manifest_blob_id_2",
                option::none(),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
        };
        
        // Third transaction: try to delete with mismatched provenance
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            // Take both DnDContents - we'll get them in order
            let dnd_content_1 = test_scenario::take_from_sender<DnDContent>(&scenario);
            let dnd_content_2 = test_scenario::take_from_sender<DnDContent>(&scenario);
            
            // Take one OCLPPackage
            let oclp_package = test_scenario::take_from_sender<OCLPPackage>(&scenario);
            
            // Try to delete dnd_content_1 with the wrong provenance
            // This should fail with E_PROVENANCE_MISMATCH
            dnd_content::delete_with_provenance(dnd_content_2, oclp_package);
            
            // Cleanup (won't reach here due to expected failure)
            sui::transfer::public_transfer(dnd_content_1, TEST_SENDER);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_destroy_entry() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint
        {
            let clock = create_test_clock(&mut scenario);
            
            dnd_content::mint_to_sender(
                string::utf8(b"Monster to Destroy"),
                61,
                TEST_MERKLE_ROOT,
                b"package_blob_id",
                string::utf8(b"1.4"),
                61,
                TEST_MANIFEST_HASH,
                b"manifest_blob_id",
                option::none(),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
        };
        
        // Second transaction: destroy via entry
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            dnd_content::destroy(dnd_content);
        };
        
        // Third transaction: verify wrapper gone
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            assert!(!test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 0);
            
            // Clean up remaining OCLPPackage
            let oclp_package = test_scenario::take_from_sender<OCLPPackage>(&scenario);
            oclp_package::delete(oclp_package);
        };
        
        test_scenario::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Accessor Tests
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fun test_get_id() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        {
            let clock = create_test_clock(&mut scenario);
            
            let dnd_content = dnd_content::mint(
                string::utf8(b"Test Monster"),
                61,
                TEST_MERKLE_ROOT,
                b"package_blob_id",
                string::utf8(b"1.4"),
                61,
                TEST_MANIFEST_HASH,
                b"manifest_blob_id",
                option::none(),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            // Verify get_id matches object::id
            let id_from_accessor = dnd_content::get_id(&dnd_content);
            let id_from_object = object::id(&dnd_content);
            assert!(id_from_accessor == id_from_object, 0);
            
            sui::transfer::public_transfer(dnd_content, TEST_SENDER);
            clock::destroy_for_testing(clock);
        };
        
        test_scenario::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Test Helper Tests
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fun test_create_test_content() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        {
            // Create a fake provenance ID
            let fake_provenance_id = object::id_from_address(@0xABC);
            
            let dnd_content = dnd_content::create_test_content(
                fake_provenance_id,
                test_scenario::ctx(&mut scenario)
            );
            
            assert!(dnd_content::get_provenance_id(&dnd_content) == fake_provenance_id, 0);
            
            sui::transfer::public_transfer(dnd_content, TEST_SENDER);
        };
        
        test_scenario::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Independent Ownership Tests
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fun test_objects_can_be_transferred_independently() {
        let other_user: address = @0xBEEF;
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint
        {
            let clock = create_test_clock(&mut scenario);
            
            dnd_content::mint_to_sender(
                string::utf8(b"Tradeable Monster"),
                61,
                TEST_MERKLE_ROOT,
                b"package_blob_id",
                string::utf8(b"1.4"),
                61,
                TEST_MANIFEST_HASH,
                b"manifest_blob_id",
                option::none(),
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            clock::destroy_for_testing(clock);
        };
        
        // Second transaction: transfer only DnDContent to other user
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            sui::transfer::public_transfer(dnd_content, other_user);
        };
        
        // Third transaction: verify ownership split
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            // TEST_SENDER still has OCLPPackage
            assert!(test_scenario::has_most_recent_for_sender<OCLPPackage>(&scenario), 0);
            // TEST_SENDER no longer has DnDContent
            assert!(!test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 1);
        };
        
        // Fourth transaction: other user has DnDContent
        test_scenario::next_tx(&mut scenario, other_user);
        {
            assert!(test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 0);
            
            // Clean up
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            dnd_content::delete(dnd_content);
        };
        
        // Clean up OCLPPackage
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let oclp_package = test_scenario::take_from_sender<OCLPPackage>(&scenario);
            oclp_package::delete(oclp_package);
        };
        
        test_scenario::end(scenario);
    }
}
