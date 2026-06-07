package com.example.supertools;

import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.item.v1.FabricItemSettings;
import net.minecraft.item.*;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class SuperToolsMod implements ModInitializer {

    public static final String MOD_ID = "super-tools";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    // Super Pickaxe — diamond tier, 100 uses, 20 attack damage, 10 attack speed, 50 mining speed
    public static final ToolMaterial SUPER_MATERIAL = new ToolMaterial() {
        @Override public int getDurability()        { return 8000; }
        @Override public float getMiningSpeedMultiplier() { return 20.0F; }
        @Override public float getAttackDamage()    { return 10.0F; }
        @Override public int getMiningLevel()       { return 3; }
        @Override public int getEnchantability()    { return 22; }
        @Override public net.minecraft.recipe.Ingredient getRepairIngredient() {
            return net.minecraft.recipe.Ingredient.ofItems(Items.NETHERITE_INGOT);
        }
    };

    public static final Item SUPER_PICKAXE = new PickaxeItem(SUPER_MATERIAL, 5, -2.8F, new FabricItemSettings());
    public static final Item SUPER_AXE     = new AxeItem(SUPER_MATERIAL, 12, -3.0F, new FabricItemSettings());
    public static final Item SUPER_SWORD   = new SwordItem(SUPER_MATERIAL, 8, -2.4F, new FabricItemSettings());

    @Override
    public void onInitialize() {
        LOGGER.info("SuperTools mod initialised — registering super tools.");

        Registry.register(Registries.ITEM, new Identifier(MOD_ID, "super_pickaxe"), SUPER_PICKAXE);
        Registry.register(Registries.ITEM, new Identifier(MOD_ID, "super_axe"),     SUPER_AXE);
        Registry.register(Registries.ITEM, new Identifier(MOD_ID, "super_sword"),   SUPER_SWORD);
    }
}
