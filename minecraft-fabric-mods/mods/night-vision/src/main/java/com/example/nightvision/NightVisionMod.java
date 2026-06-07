package com.example.nightvision;

import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class NightVisionMod implements ModInitializer {

    public static final String MOD_ID = "night-vision";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    private static final int EFFECT_DURATION = 400;

    @Override
    public void onInitialize() {
        LOGGER.info("NightVision mod initialised — all players will have permanent night vision.");

        ServerTickEvents.END_SERVER_TICK.register(this::onServerTick);
    }

    private void onServerTick(MinecraftServer server) {
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            StatusEffectInstance current = player.getStatusEffect(StatusEffects.NIGHT_VISION);
            if (current == null || current.getDuration() < EFFECT_DURATION / 2) {
                player.addStatusEffect(
                    new StatusEffectInstance(StatusEffects.NIGHT_VISION, EFFECT_DURATION, 0, false, false, false)
                );
            }
        }
    }
}
