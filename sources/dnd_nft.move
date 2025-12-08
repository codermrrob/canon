module dnd_nft::dnd_content {
    use sui::clock::Clock;
    use sui::display;
    use sui::dynamic_object_field as dof;
    use sui::event;
    use sui::package::Publisher;
    use oclp::oclp_package::{Self, OCLPPackage};
    use std::string;

    // ═══════════════════════════════════════════════════════════════════════
    // Constants
    // ═══════════════════════════════════════════════════════════════════════

    const PROVENANCE_KEY: vector<u8> = b"provenance";

    // ═══════════════════════════════════════════════════════════════════════
    // Structs
    // ═══════════════════════════════════════════════════════════════════════

    /// Domain NFT wrapper for D&D content
    /// 
    /// This struct serves as a domain identifier. Only this module can
    /// create `DnDContent` objects, so querying by this type guarantees
    /// the content was minted through the D&D domain contract.
    /// 
    /// The OCLPPackage is attached as a dynamic object field, enabling:
    /// - Protocol-level discovery (query all OCLPPackage objects)
    /// - Domain-level discovery (query all DnDContent objects)
    /// - Paired ownership (OCLPPackage moves with DnDContent)
    /// - Interoperability (manifest extensions describe domain context)
    public struct DnDContent has key, store {
        id: object::UID,
        content_package_name: string::String,
        world: string::String,
        system: string::String,
        content_category: string::String,
    }

    /// Event emitted when Display is initialized
    public struct DisplayInitialized has copy, drop {
        display_id: address,
    }

    /// Event emitted when D&D content is minted
    public struct DnDMintCompleted has copy, drop {
        dnd_content_id: object::ID,
        provenance_id: object::ID,
        creator: address,
        minted_at_ms: u64,
    }

    /// Event emitted when D&D content is deleted
    public struct DnDDeleteCompleted has copy, drop {
        dnd_content_id: object::ID,
        provenance_id: object::ID,
        content_package_name: string::String,
        world: string::String,
        system: string::String,
        content_category: string::String,
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Minting
    // ═══════════════════════════════════════════════════════════════════════

    /// Mint D&D content with provenance
    /// 
    /// This function:
    /// 1. Calls the OCLP protocol to mint an OCLPPackage
    /// 2. Creates a DnDContent wrapper
    /// 3. Attaches the OCLPPackage as a dynamic object field
    /// 4. Returns the DnDContent (which owns the OCLPPackage)
    /// 
    /// The OCLPPackage is attached via dynamic object field, so:
    /// - It remains independently discoverable (query all OCLPPackage objects)
    /// - It moves with DnDContent when transferred (paired ownership)
    /// 
    /// All domain-specific metadata lives in the manifest JSON under
    /// extensions["dnd-creators"], which is cryptographically bound
    /// via the manifest_hash in OCLPPackage.
    public fun mint(
        content_package_name: string::String,
        world: string::String,
        system: string::String,
        content_category: string::String,
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

        // Capture metadata before attaching
        let provenance_id = oclp_package::get_id(&provenance);
        let creator = tx_context::sender(ctx);
        let minted_at_ms = oclp_package::get_created_at(&provenance);

        // Create domain wrapper with D&D-specific fields
        let mut dnd_content = DnDContent {
            id: object::new(ctx),
            content_package_name,
            world,
            system,
            content_category,
        };

        // Attach OCLPPackage as dynamic object field (preserves independent discoverability)
        dof::add(&mut dnd_content.id, PROVENANCE_KEY, provenance);

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
        world: string::String,
        system: string::String,
        content_category: string::String,
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
            world,
            system,
            content_category,
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
        object::id(dof::borrow<vector<u8>, OCLPPackage>(&content.id, PROVENANCE_KEY))
    }

    /// Borrow the provenance package immutably
    public fun borrow_provenance(content: &DnDContent): &OCLPPackage {
        dof::borrow<vector<u8>, OCLPPackage>(&content.id, PROVENANCE_KEY)
    }

    /// Get the content package name
    public fun get_content_package_name(content: &DnDContent): string::String {
        content.content_package_name
    }

    /// Get the world
    public fun get_world(content: &DnDContent): string::String {
        content.world
    }

    /// Get the system
    public fun get_system(content: &DnDContent): string::String {
        content.system
    }

    /// Get the content category
    public fun get_content_category(content: &DnDContent): string::String {
        content.content_category
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Display
    // ═══════════════════════════════════════════════════════════════════════

    /// Initialize the Display for DnDContent
    /// 
    /// Creates a Display object that defines how DnDContent appears in
    /// wallets and marketplaces. Must be called with a Publisher for this package.
    entry fun init_display(
        pub: &Publisher,
        ctx: &mut tx_context::TxContext
    ) {
        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"world"),
            string::utf8(b"system"),
            string::utf8(b"content_category"),
        ];

        let values = vector[
            string::utf8(b"{content_package_name}"),
            string::utf8(b"Canon DnD Domain Content"),
            string::utf8(b"{world}"),
            string::utf8(b"{system}"),
            string::utf8(b"{content_category}"),
        ];

        let mut disp = display::new_with_fields<DnDContent>(pub, keys, values, ctx);
        display::update_version(&mut disp);

        let display_addr = object::id_address(&disp);
        transfer::public_transfer(disp, tx_context::sender(ctx));

        event::emit(DisplayInitialized { display_id: display_addr });
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Destruction
    // ═══════════════════════════════════════════════════════════════════════

    /// Delete the DnDContent and its attached OCLPPackage
    /// 
    /// Since the OCLPPackage is attached as a dynamic object field,
    /// both are deleted together. Emits DnDDeleteCompleted before deletion.
    public fun delete(content: DnDContent) {
        // Capture IDs and properties before destruction
        let dnd_content_id = object::id(&content);
        let provenance_id = get_provenance_id(&content);

        let DnDContent {
            mut id,
            content_package_name,
            world,
            system,
            content_category,
        } = content;

        // Emit event before deletion
        event::emit(DnDDeleteCompleted {
            dnd_content_id,
            provenance_id,
            content_package_name,
            world,
            system,
            content_category,
        });

        let provenance: OCLPPackage = dof::remove(&mut id, PROVENANCE_KEY);
        oclp_package::delete(provenance);
        object::delete(id);
    }

    /// Destroy a DnDContent and its provenance (entry point convenience)
    entry fun destroy(content: DnDContent) {
        delete(content);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Test-only Functions
    // ═══════════════════════════════════════════════════════════════════════

    #[test_only]
    /// Create a test DnDContent for unit tests
    /// 
    /// Requires an OCLPPackage to attach as the provenance.
    public fun create_test_content(
        provenance: OCLPPackage,
        world: string::String,
        system: string::String,
        content_category: string::String,
        ctx: &mut tx_context::TxContext
    ): DnDContent {
        let content_package_name = oclp_package::get_package_name(&provenance);
        let mut dnd_content = DnDContent {
            id: object::new(ctx),
            content_package_name,
            world,
            system,
            content_category,
        };
        dof::add(&mut dnd_content.id, PROVENANCE_KEY, provenance);
        dnd_content
    }
}
