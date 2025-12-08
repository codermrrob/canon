#[test_only]
module dnd_nft::dnd_content_tests {
    use sui::test_scenario;
    use sui::clock;
    use std::string;
    use oclp::oclp_package::{Self};
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

    const TEST_WORLD: vector<u8> = b"Forgotten Realms";
    const TEST_SYSTEM: vector<u8> = b"D&D 5e";
    const TEST_CONTENT_CATEGORY: vector<u8> = b"Monster";

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
    fun test_mint_creates_dnd_content_with_attached_provenance() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint via domain
        {
            let mut clock = create_test_clock(&mut scenario);
            clock::set_for_testing(&mut clock, 1000);
            
            let dnd_content = dnd_content::mint(
                string::utf8(b"Elder Void Wurm"),
                string::utf8(TEST_WORLD),
                string::utf8(TEST_SYSTEM),
                string::utf8(TEST_CONTENT_CATEGORY),
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
        
        // Second transaction: verify DnDContent exists with attached provenance
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            // Should have DnDContent
            assert!(test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 0);
            
            // Verify provenance is accessible via borrow
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            let provenance = dnd_content::borrow_provenance(&dnd_content);
            assert!(oclp_package::get_package_name(provenance) == string::utf8(b"Elder Void Wurm"), 1);
            
            test_scenario::return_to_sender(&scenario, dnd_content);
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
                string::utf8(TEST_WORLD),
                string::utf8(TEST_SYSTEM),
                string::utf8(TEST_CONTENT_CATEGORY),
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
        
        // Second transaction: verify provenance_id matches attached OCLPPackage id
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            
            // The DnDContent's provenance_id should match the attached OCLPPackage's id
            let provenance_id = dnd_content::get_provenance_id(&dnd_content);
            let provenance = dnd_content::borrow_provenance(&dnd_content);
            let package_id = oclp_package::get_id(provenance);
            
            assert!(provenance_id == package_id, 0);
            
            test_scenario::return_to_sender(&scenario, dnd_content);
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
                string::utf8(TEST_WORLD),
                string::utf8(TEST_SYSTEM),
                string::utf8(TEST_CONTENT_CATEGORY),
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
        
        // Second transaction: verify sender owns DnDContent with attached provenance
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            let provenance = dnd_content::borrow_provenance(&dnd_content);
            
            // Verify package data is correct
            assert!(oclp_package::get_package_name(provenance) == string::utf8(b"Direct Mint Monster"), 0);
            
            test_scenario::return_to_sender(&scenario, dnd_content);
        };
        
        test_scenario::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Delete Tests
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fun test_delete_removes_both() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint
        {
            let clock = create_test_clock(&mut scenario);
            
            dnd_content::mint_to_sender(
                string::utf8(b"Monster to Delete"),
                string::utf8(TEST_WORLD),
                string::utf8(TEST_SYSTEM),
                string::utf8(TEST_CONTENT_CATEGORY),
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
        
        // Second transaction: delete (removes both DnDContent and attached OCLPPackage)
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            dnd_content::delete(dnd_content);
        };
        
        // Third transaction: verify both are gone
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            // DnDContent should be gone
            assert!(!test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 0);
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
                string::utf8(TEST_WORLD),
                string::utf8(TEST_SYSTEM),
                string::utf8(TEST_CONTENT_CATEGORY),
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
        
        // Third transaction: verify both are gone
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            assert!(!test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 0);
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
                string::utf8(TEST_WORLD),
                string::utf8(TEST_SYSTEM),
                string::utf8(TEST_CONTENT_CATEGORY),
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
            // Create a test OCLPPackage
            let provenance = oclp_package::create_test_package(
                string::utf8(b"Test Package"),
                TEST_MERKLE_ROOT,
                test_scenario::ctx(&mut scenario)
            );
            let expected_provenance_id = oclp_package::get_id(&provenance);
            
            let dnd_content = dnd_content::create_test_content(
                provenance,
                string::utf8(TEST_WORLD),
                string::utf8(TEST_SYSTEM),
                string::utf8(TEST_CONTENT_CATEGORY),
                test_scenario::ctx(&mut scenario)
            );
            
            assert!(dnd_content::get_provenance_id(&dnd_content) == expected_provenance_id, 0);
            
            // Clean up
            dnd_content::delete(dnd_content);
        };
        
        test_scenario::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Paired Ownership Tests
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fun test_transfer_moves_both_objects_together() {
        let other_user: address = @0xBEEF;
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // First transaction: mint
        {
            let clock = create_test_clock(&mut scenario);
            
            dnd_content::mint_to_sender(
                string::utf8(b"Tradeable Monster"),
                string::utf8(TEST_WORLD),
                string::utf8(TEST_SYSTEM),
                string::utf8(TEST_CONTENT_CATEGORY),
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
        
        // Second transaction: transfer DnDContent to other user
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            sui::transfer::public_transfer(dnd_content, other_user);
        };
        
        // Third transaction: verify TEST_SENDER no longer has DnDContent
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            assert!(!test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 0);
        };
        
        // Fourth transaction: other user has DnDContent with attached provenance
        test_scenario::next_tx(&mut scenario, other_user);
        {
            assert!(test_scenario::has_most_recent_for_sender<DnDContent>(&scenario), 0);
            
            // Verify provenance is still accessible
            let dnd_content = test_scenario::take_from_sender<DnDContent>(&scenario);
            let provenance = dnd_content::borrow_provenance(&dnd_content);
            assert!(oclp_package::get_package_name(provenance) == string::utf8(b"Tradeable Monster"), 1);
            
            // Clean up
            dnd_content::delete(dnd_content);
        };
        
        test_scenario::end(scenario);
    }
}
