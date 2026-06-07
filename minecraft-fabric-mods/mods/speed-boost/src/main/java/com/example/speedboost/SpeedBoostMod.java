package com.example.speedboost;

import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class SpeedBoostMod implements ModInitializer {

    public static final String MOD_ID = "speed-boost";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    // Duration in ticks (200 = 10 seconds); refreshed each server tick so it never expires
    private static final int EFFECT_DURATION = 200;
    // Amplifier 1 = Speed II
    private static final int SPEED_AMPLIFIER = 1;

    @Override
    public void onInitialize() {
        LOGGER.info("SpeedBoost mod initialised — all players will receive Speed II.");

        ServerTickEvents.END_SERVER_TICK.register(this::onServerTick);
    }

    private void onServerTick(MinecraftServer server) {
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            StatusEffectInstance current = player.getStatusEffect(StatusEffects.SPEED);
            // Only reapply when the remaining duration drops below half to reduce churn
            if (current == null || current.getDuration() < EFFECT_DURATION / 2) {
                player.addStatusEffect(
                    new StatusEffectInstance(StatusEffects.SPEED, EFFECT_DURATION, SPEED_AMPLIFIER, false, false, true)
                );
            }
        }
    }
}
