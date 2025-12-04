module dnd_domain::dnd_content {
    use sui::clock::Clock;
    use sui::event;
    use oclp::oclp_package::{Self, OCLPPackage};
    use std::string;

    // ═══════════════════════════════════════════════════════════════════════
    // Error Codes
    // ═══════════════════════════════════════════════════════════════════════
    
    const E_PROVENANCE_MISMATCH: u64 = 1;

    // ═══════════════════════════════════════════════════════════════════════
    // Structs
    // ═══════════════════════════════════════════════════════════════════════

    /// Domain NFT wrapper for D&D content
    /// 
    /// This struct serves as a domain identifier. Only this module can
    /// create `DnDContent` objects, so querying by this type guarantees
    /// the content was minted through the D&D domain contract.
    /// 
    /// The wrapper references the protocol-level OCLPPackage by ID,
    /// enabling:
    /// - Protocol-level discovery (query all OCLPPackage objects)
    /// - Domain-level discovery (query all DnDContent objects)
    /// - Interoperability (manifest extensions describe domain context)
    public struct DnDContent has key, store {
        id: object::UID,
        provenance_id: object::ID,
    }

    /// Event emitted when D&D content is minted
    public struct DnDMintCompleted has copy, drop {
        dnd_content_id: object::ID,
        provenance_id: object::ID,
        creator: address,
        minted_at_ms: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Minting
    // ═══════════════════════════════════════════════════════════════════════

    /// Mint D&D content with provenance
    /// 
    /// This function:
    /// 1. Calls the OCLP protocol to mint an OCLPPackage
    /// 2. Creates a DnDContent wrapper referencing the package
    /// 3. Transfers the OCLPPackage to the sender
    /// 4. Returns the DnDContent wrapper
    /// 
    /// The caller ends up owning both:
    /// - OCLPPackage (protocol-level, independently discoverable)
    /// - DnDContent (domain-level, references the package)
    /// 
    /// All domain-specific metadata lives in the manifest JSON under
    /// extensions["dnd-creators"], which is cryptographically bound
    /// via the manifest_hash in OCLPPackage.
    #[allow(lint(self_transfer))]
    public fun mint(
        content_package_name: string::String,
        merkle_integrity_algo: u8,
        merkle_root: vector<u8>,
        package_storage_blob_ref: vector<u8>,
        manifest_version: string::String,
        manifest_integrity_algo: u8,
        manifest_hash: vector<u8>,
        manifest_storage_blob_ref: vector<u8>,
        parent_manifest_id: option::Option<object::ID>,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ): DnDContent {
        // Mint the protocol-level provenance NFT
        let provenance = oclp_package::mint(
            content_package_name,
            merkle_integrity_algo,
            merkle_root,
            package_storage_blob_ref,
            manifest_version,
            manifest_integrity_algo,
            manifest_hash,
            manifest_storage_blob_ref,
            parent_manifest_id,
            clock,
            ctx
        );

        // Capture the provenance ID before transferring
        let provenance_id = oclp_package::get_id(&provenance);
        let creator = tx_context::sender(ctx);
        let minted_at_ms = oclp_package::get_created_at(&provenance);

        // Transfer OCLPPackage to sender (they own it independently)
        transfer::public_transfer(provenance, creator);

        // Create domain wrapper
        let dnd_content = DnDContent {
            id: object::new(ctx),
            provenance_id,
        };

        let dnd_content_id = object::id(&dnd_content);

        // Emit domain event
        event::emit(DnDMintCompleted {
            dnd_content_id,
            provenance_id,
            creator,
            minted_at_ms,
        });

        dnd_content
    }

    /// Mint D&D content and transfer directly to sender
    /// 
    /// Convenience entry function for direct minting.
    #[allow(lint(self_transfer))]
    entry fun mint_to_sender(
        content_package_name: string::String,
        merkle_integrity_algo: u8,
        merkle_root: vector<u8>,
        package_storage_blob_ref: vector<u8>,
        manifest_version: string::String,
        manifest_integrity_algo: u8,
        manifest_hash: vector<u8>,
        manifest_storage_blob_ref: vector<u8>,
        parent_manifest_id: option::Option<object::ID>,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        let dnd_content = mint(
            content_package_name,
            merkle_integrity_algo,
            merkle_root,
            package_storage_blob_ref,
            manifest_version,
            manifest_integrity_algo,
            manifest_hash,
            manifest_storage_blob_ref,
            parent_manifest_id,
            clock,
            ctx
        );

        transfer::public_transfer(dnd_content, tx_context::sender(ctx));
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Accessor Functions
    // ═══════════════════════════════════════════════════════════════════════

    /// Get the domain content ID
    public fun get_id(content: &DnDContent): object::ID {
        object::id(content)
    }

    /// Get the referenced provenance package ID
    public fun get_provenance_id(content: &DnDContent): object::ID {
        content.provenance_id
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Destruction
    // ═══════════════════════════════════════════════════════════════════════

    /// Delete a DnDContent wrapper
    /// 
    /// This only deletes the domain wrapper. The OCLPPackage continues
    /// to exist independently and must be deleted separately if desired.
    public fun delete(content: DnDContent) {
        let DnDContent { id, provenance_id: _ } = content;
        object::delete(id);
    }

    /// Delete both the DnDContent wrapper and its associated OCLPPackage
    /// 
    /// Convenience function for deleting both in one call.
    /// Verifies the provenance matches before deletion.
    public fun delete_with_provenance(
        content: DnDContent,
        provenance: OCLPPackage
    ) {
        assert!(
            oclp_package::get_id(&provenance) == content.provenance_id,
            E_PROVENANCE_MISMATCH
        );

        let DnDContent { id, provenance_id: _ } = content;
        object::delete(id);
        oclp_package::delete(provenance);
    }

    /// Destroy a DnDContent wrapper (entry point convenience)
    entry fun destroy(content: DnDContent) {
        delete(content);
    }

    /// Destroy both wrapper and provenance (entry point convenience)
    entry fun destroy_with_provenance(
        content: DnDContent,
        provenance: OCLPPackage
    ) {
        delete_with_provenance(content, provenance);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Test-only Functions
    // ═══════════════════════════════════════════════════════════════════════

    #[test_only]
    /// Create a test DnDContent for unit tests
    public fun create_test_content(
        provenance_id: object::ID,
        ctx: &mut tx_context::TxContext
    ): DnDContent {
        DnDContent {
            id: object::new(ctx),
            provenance_id,
        }
    }
}
