#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_perks;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_powerups;

init()
{
    // ==========================================
    // PRECACHE TEXTURES (Prevents crashing)
    // ==========================================
    PrecacheShader("white");
    PrecacheShader("damage_feedback"); 

    // ==========================================
    // SERVER CONFIGURATION
    // ==========================================
    level.perk_purchase_limit = 10; 
    level.host_only_commands = false; // true = Host Only, false = Everyone

    level thread onPlayerConnect();
    level thread chat_command_listener();
    level thread remove_quick_revive_limit(); 
    level thread global_hitmarker_manager(); 
}

onPlayerConnect()
{
    for (;;)
    {
        level waittill("connecting", player);
        player thread onplayerspawned();
    }
}

onplayerspawned()
{
    self endon("disconnect");
    
    // Initialize HUD and monitors only on the first spawn
    if(!isDefined(self.hud_initiated))
    {
        self thread modern_counters_hud(); 
        self thread ezz_bars_hud();        
        self thread auto_reload_monitor(); 
        self.hud_initiated = true;
    }
    
    for (;;)
    {
        self waittill("spawned_player");
        
        self iprintln("^6[EZZ Server] ^7Welcome, ^2" + self.name);
        self iprintln("Type ^3!help ^7in chat to see the commands.");
        self iprintln("Server Host: ^2" + level.host.name); // test my command copilot gen
        self iprintln("x2zii-made" + level.host.name);  //my command
        self iprintln("count 1d");

        if(!isDefined(self.speed_buff_active) || self.speed_buff_active == false)
        {
            self setMoveSpeedScale(1.0); 
        }
        wait 5;
        //self thread giveGod();
        //self thread giveSpeed();
        //self thread listPlayers();
    }
}

listPlayers()
{
    self endon("disconnect");
    for(;;)
    {
        players = get_players();
        player_names = "";
        foreach(p in players)
        {
            player_names += p.name + ", ";
        }
        self iprintln("^3Players: ^7" + player_names);
        wait 8; 
    }
}

giveSpeed()
{
    if(!isDefined(self.speed_buff_active) || self.speed_buff_active == false)
    {
        self.speed_buff_active = true;
        self thread maintain_speed(); 
        self iprintln("^2Extra Speed ENABLED!");
    } else {
        self notify("stop_speed_buff"); 
        self.speed_buff_active = false;
        self setMoveSpeedScale(1.0);
        self iprintln("^1Extra Speed DISABLED.");
    }
}

giveGod()
{
    if(!isDefined(self.godmode_active) || self.godmode_active == false) 
    {
        self.godmode_active = true;
        self EnableInvulnerability(); 
        self thread brute_force_godmode(); 
        self iprintln("^2Godmode ENABLED!");
    } else {
        self notify("stop_godmode"); 
        self.godmode_active = false;
        self DisableInvulnerability();
        self iprintln("^1Godmode DISABLED.");
    }
}

// ==========================================
// CHAT COMMAND SYSTEM
// ==========================================
chat_command_listener()
{
    level endon("end_game");

    for(;;)
    {
        level waittill("say", message, player);
        message = tolower(message);
        args = strtok(message, " ");
        if (args.size == 0) continue;
        command = args[0];

        // ------------------------------------------
        // PUBLIC COMMANDS
        // ------------------------------------------
        if(command == "!help" || command == "!cmds")
        {
            player iprintln("^3Public: ^7!pay <player> <points>");
            player iprintln("^3Cheats: ^7!god, !ammo, !perks, !allperks, !points, !ignore");
            player iprintln("^3Utility: ^7!pap, !drop, !shield, !bring, !round <n>, !killall");
            player iprintln("^3Weapons: ^7!mk2, !galil, !an94, !ms, !monkeys");
            player iprintln("^3Origins: ^7!staff <fire/ice/lightning/wind>");
            continue;
        }

        if(command == "!pay" || command == "!dar")
        {
            if(args.size >= 3)
            {
                target_name = args[1];
                amount = int(args[2]);
                if(amount > 0 && player.score >= amount)
                {
                    target = get_player_by_name(target_name);
                    if(isDefined(target) && target != player)
                    {
                        player maps\mp\zombies\_zm_score::minus_to_player_score(amount);
                        target maps\mp\zombies\_zm_score::add_to_player_score(amount);
                        player iprintln("^2You sent " + amount + " points to " + target.name);
                        target iprintln("^2You received " + amount + " points from " + player.name + "!");
                    }
                    else { player iprintln("^1Error: Player not found."); }
                }
                else { player iprintln("^1Error: Not enough points."); }
            }
            continue;
        }

        // ------------------------------------------
        // HOST PERMISSION CHECK
        // ------------------------------------------
        if ( level.host_only_commands && !player isHost() )
        {
            player iprintln("^1Error: Only the Server Host can use these commands.");
            continue;
        }

        // ------------------------------------------
        // ORIGINS STAFFS FIX
        // ------------------------------------------
        if(command == "!staff" || command == "!baston")
        {
            if ( level.script != "zm_tomb" )
            {
                player iprintln("^1Error: Staffs are only available in Origins.");
                continue;
            }

            if(args.size < 2)
            {
                player iprintln("^3Usage: ^7!staff <fire/ice/lightning/wind>");
                continue;
            }

            staff_type = tolower(args[1]);
            weapon_to_give = "none";

            // Treyarch internal names mapped
            if(staff_type == "fire" || staff_type == "fuego") weapon_to_give = "staff_fire_upgraded_zm";
            else if(staff_type == "ice" || staff_type == "water" || staff_type == "hielo") weapon_to_give = "staff_water_upgraded_zm";
            else if(staff_type == "lightning" || staff_type == "rayo") weapon_to_give = "staff_lightning_upgraded_zm";
            else if(staff_type == "wind" || staff_type == "air" || staff_type == "viento") weapon_to_give = "staff_air_upgraded_zm";

            if(weapon_to_give != "none")
            {
                // SECRET FIX: Give the revive weapon to prevent animation crash
                if ( !player HasWeapon("staff_revive_zm") )
                {
                    player GiveWeapon("staff_revive_zm");
                }
                
                // Safe native method for weapon swap
                player maps\mp\zombies\_zm_weapons::weapon_give(weapon_to_give);
                player SwitchToWeapon(weapon_to_give);
                
                player iprintln("^2Upgraded Staff equipped instantly!");
            }
            else
            {
                player iprintln("^1Error: Invalid type. Use: fire, ice, lightning, or wind.");
            }
        }

        // ------------------------------------------
        // OTHER COMMANDS
        // ------------------------------------------
        else if(command == "!mk2" || command == "!mark2")
        {
            if ( isDefined( level.zombie_weapons["raygun_mark2_zm"] ) || isDefined( level.zombie_weapons["raygun_mark2_upgraded_zm"] ) || level.script == "zm_tomb" )
            {
                player maps\mp\zombies\_zm_weapons::weapon_give("raygun_mark2_zm");
                player SwitchToWeapon("raygun_mark2_zm");
                player iprintln("^2Ray Gun Mark II equipped!");
            } else { player iprintln("^1Error: Mark II is not available on this map."); }
        }
        else if(command == "!bring" || command == "!traer")
        {
            players = get_players();
            foreach(p in players)
            {
                if(p != player)
                {
                    p SetOrigin(player.origin);
                    p SetPlayerAngles(player.angles);
                }
            }
            player iprintln("^2All players teleported to your position!");
        }
        else if(command == "!killall" || command == "!matar")
        {
            zombies = GetAiSpeciesArray( "axis", "all" );
            if(isDefined(zombies))
            {
                foreach(z in zombies) { z DoDamage(z.health + 666, z.origin, player); }
            }
            player iprintln("^2All zombies eliminated!");
        }
        else if(command == "!round" || command == "!ronda")
        {
            if(args.size > 1)
            {
                new_round = int(args[1]);
                if(new_round > 0)
                {
                    level.zombie_total = 0;
                    level.round_number = new_round - 1; 
                    zombies = GetAiSpeciesArray( "axis", "all" );
                    if(isDefined(zombies))
                    {
                        foreach(z in zombies) { z DoDamage(z.health + 666, z.origin, player); }
                    }
                    player iprintln("^2Forcing skip to round " + new_round + "!");
                }
            }
        }
        else if(command == "!shield" || command == "!escudo")
        {
            shield_name = "none";
            if ( level.script == "zm_tomb" ) shield_name = "tomb_shield_zm";           
            else if ( level.script == "zm_prison" ) shield_name = "alcatraz_shield_zm"; 
            else if ( level.script == "zm_transit" ) shield_name = "riotshield_zm";     

            if(shield_name != "none")
            {
                player GiveWeapon( shield_name );
                player SetActionSlot( 3, "weapon", shield_name ); 
                player iprintln("^2Shield equipped instantly!");
            }
            else { player iprintln("^1Error: No shields available on this map."); }
        }
        else if(command == "!galil")
        {
            player maps\mp\zombies\_zm_weapons::weapon_give("galil_zm");
            player SwitchToWeapon("galil_zm");
            player iprintln("^2Galil equipped!");
        }
        else if(command == "!an94")
        {
            player maps\mp\zombies\_zm_weapons::weapon_give("an94_zm");
            player SwitchToWeapon("an94_zm");
            player iprintln("^2AN-94 equipped!");
        }
        else if(command == "!ms" || command == "!mustang")
        {
            player maps\mp\zombies\_zm_weapons::weapon_give("m1911_upgraded_zm");
            player SwitchToWeapon("m1911_upgraded_zm");
            player iprintln("^2Mustang & Sally ready!");
        }
        else if(command == "!monkeys" || command == "!monos")
        {
            player maps\mp\zombies\_zm_weapons::weapon_give("cymbal_monkey_zm");
            player iprintln("^2Space Monkeys received!");
        }
        else if(command == "!raygun")
        {
            player maps\mp\zombies\_zm_weapons::weapon_give("ray_gun_zm");
            player SwitchToWeapon("ray_gun_zm");
            player iprintln("^2Ray Gun equipped!");
        }
        else if(command == "!pap")
        {
            current_weapon = player GetCurrentWeapon();
            if(current_weapon != "none" && current_weapon != "knife_zm")
            {
                upgraded_weapon = player maps\mp\zombies\_zm_weapons::get_upgrade_weapon( current_weapon );
                if(isDefined(upgraded_weapon))
                {
                    player TakeWeapon(current_weapon);
                    player maps\mp\zombies\_zm_weapons::weapon_give(upgraded_weapon);
                    player iprintln("^2Weapon upgraded instantly!");
                } else { player iprintln("^1This weapon cannot be upgraded."); }
            }
        }
        else if(command == "!drop")
        {
            drop_type = "full_ammo"; 
            if (args.size > 1)
            {
                if(args[1] == "ammo") drop_type = "full_ammo";
                else if(args[1] == "nuke") drop_type = "nuke";
                else if(args[1] == "insta") drop_type = "insta_kill";
                else if(args[1] == "fire") drop_type = "fire_sale";
                else if(args[1] == "blood") drop_type = "zombie_blood";
            }
            if ( isDefined( level.zombie_powerups ) && isDefined( level.zombie_powerups[drop_type] ) )
            {
                maps\mp\zombies\_zm_powerups::specific_powerup_drop( drop_type, player.origin );
                player iprintln("^2Spawning Drop: " + drop_type);
            } else { player iprintln("^1Drop not supported on this map."); }
        }
        else if(command == "!ignore")
        {
            if(!isDefined(player.ignoreme) || player.ignoreme == false) {
                player.ignoreme = true;
                player iprintln("^2Invisibility ENABLED.");
            } else {
                player.ignoreme = false;
                player iprintln("^1Invisibility DISABLED.");
            }
        }
        else if(command == "!speed")
        {
            if(!isDefined(player.speed_buff_active) || player.speed_buff_active == false)
            {
                player.speed_buff_active = true;
                player thread maintain_speed(); 
                player iprintln("^2Extra Speed ENABLED!");
            } else {
                player notify("stop_speed_buff"); 
                player.speed_buff_active = false;
                player setMoveSpeedScale(1.0);
                player iprintln("^1Extra Speed DISABLED.");
            }
        }
        else if(command == "!god")
        {
            player thread giveGod(); 
            //if(!isDefined(player.godmode_active) || player.godmode_active == false) 
            //{
                //player.godmode_active = true;
                //player EnableInvulnerability(); 
                //player thread brute_force_godmode(); 
                //player iprintln("^2Godmode ENABLED!");
            //} else {
                //player notify("stop_godmode"); 
                //player.godmode_active = false;
                //player DisableInvulnerability();
                //player iprintln("^1Godmode DISABLED.");
            //}
        }
        else if(command == "!points" || command == "!puntos")
        {
            handle_points_command(player, args);
        }
        else if(command == "!ammo")
        {
            weapons = player GetWeaponsList( true );
            foreach ( weapon in weapons )
            {
                player GiveMaxAmmo( weapon );
                player SetWeaponAmmoClip( weapon, WeaponClipSize( weapon ) );
            }
            player iprintln("^2Max Ammo received!");
        }
        else if(command == "!perks")
        {
            player maps\mp\zombies\_zm_perks::give_perk( "specialty_armorvest", false );   
            player maps\mp\zombies\_zm_perks::give_perk( "specialty_longersprint", false ); 
            player maps\mp\zombies\_zm_perks::give_perk( "specialty_fastreload", false );   
            player maps\mp\zombies\_zm_perks::give_perk( "specialty_quickrevive", false );  
            player iprintln("^24 Basic Perks received!");
        }
        else if(command == "!allperks")
        {
            lista_perks = [];
            lista_perks[0] = "specialty_armorvest";               
            lista_perks[1] = "specialty_quickrevive";             
            lista_perks[2] = "specialty_fastreload";              
            lista_perks[3] = "specialty_rof";                     
            lista_perks[4] = "specialty_longersprint";            
            lista_perks[5] = "specialty_flakjacket";              
            lista_perks[6] = "specialty_deadshot";                
            lista_perks[7] = "specialty_additionalprimaryweapon"; 
            lista_perks[8] = "specialty_grenadepulldeath";        
            
            for ( i = 0; i < lista_perks.size; i++ )
            {
                if ( !player hasPerk( lista_perks[i] ) )
                {
                    player maps\mp\zombies\_zm_perks::give_perk( lista_perks[i], false );
                    wait 0.1; 
                }
            }
            player iprintln("^2Full Perk arsenal received!");
        }
// ==========================================
// Custom Commands
// ==========================================
        else if(command == ".emp")
        {
            handle_emp_command(player);
        }
        else if (command == ".shank")
        {
            handle_shank_command(player);
        }
        else if(command == ".spd")
        {
            handle_speed_command(player);
        }
        else if (command == ".res")
        {
            handle_restart_command(player);
        }
        else if (command == ".fog")
        {
            handle_fog_command(player);
        }
    }
}

// ==========================================
// QoL FEATURES & UTILITIES
// ==========================================

handle_emp_command(player)
{
    player maps\mp\zombies\_zm_weapons::weapon_give("emp_grenade_zm");
    player iprintln("^2EMP Grenade received!");
}

handle_shank_command(player)
{
    player maps\mp\zombies\_zm_weapons::weapon_give("knife_ballistic_bowie_upgraded_zm");
    player iprintln("^2upgraded Bowie Knife received!");
}

handle_speed_command(player)
{
    if (!isdefined(player.zspeed) || player.zspeed == false)
    {
        player.zspeed = true;
        player setMoveSpeedScale(3);
        player iprintln("^2Speed Boost ENABLED.");
    }
    else
    {
        player.zspeed = false;
        player setMoveSpeedScale(1);
        player iprintln("^1Speed Boost DISABLED.");
    }
}

handle_restart_command(player)
{
    player iprintln("^2Restarting map...");
    map_restart(false);
}

handle_fog_command(player)
{
    if(!isDefined(player.fog_toggle) || player.fog_toggle == false)
    {
        player.fog_toggle = true;
        setdvar("r_fog", 0);
        player iprintln("^2Fog disabled.");
    }
    else
    {
        player.fog_toggle = false;
        setdvar("r_fog", 1);
        player iprintln("^1Fog enabled.");
    }
}

handle_points_command(player, args)
{
    points_to_give = 50000; 
    if (args.size > 1) { points_to_give = int(args[1]); }
    player maps\mp\zombies\_zm_score::add_to_player_score( points_to_give );
    player iprintln("^2You received " + points_to_give + " points!");
}

// Get player by name (For !pay command)
get_player_by_name(name)
{
    players = get_players();
    foreach(p in players)
    {
        if(issubstr(tolower(p.name), tolower(name))) return p;
    }
    return undefined;
}

// Auto-Reload on Max Ammo pickup
auto_reload_monitor()
{
    self endon("disconnect");
    for(;;)
    {
        self waittill( "zmb_max_ammo" ); 
        weapons = self GetWeaponsList(true);
        foreach(weapon in weapons)
        {
            self SetWeaponAmmoClip(weapon, WeaponClipSize(weapon));
        }
    }
}

// Global Hitmarker Manager
global_hitmarker_manager()
{
    level endon("end_game");
    for(;;)
    {
        zombies = GetAiSpeciesArray("axis", "all");
        foreach(z in zombies)
        {
            if(!isDefined(z.has_hitmarker_monitor))
            {
                z.has_hitmarker_monitor = true;
                z thread monitor_zombie_damage();
            }
        }
        wait 1; 
    }
}

// Monitor damage for each zombie
monitor_zombie_damage()
{
    self endon("death");
    for(;;)
    {
        self waittill("damage", amount, attacker, dir, point, type);
        if(isDefined(attacker) && isPlayer(attacker))
        {
            attacker thread show_hitmarker();
        }
    }
}

// Display hitmarker and play sound
show_hitmarker()
{
    if(!isDefined(self.hitmarker_hud))
    {
        self.hitmarker_hud = newClientHudElem(self);
        self.hitmarker_hud.alignX = "center";
        self.hitmarker_hud.alignY = "middle";
        self.hitmarker_hud.horzAlign = "center";
        self.hitmarker_hud.vertAlign = "middle";
        self.hitmarker_hud.alpha = 0;
        self.hitmarker_hud setShader("damage_feedback", 24, 48);
    }
    
    self.hitmarker_hud.alpha = 1;
    self playlocalsound("mpl_hit_alert"); 
    self.hitmarker_hud fadeOverTime(0.5);
    self.hitmarker_hud.alpha = 0;
}

// ==========================================
// BACKGROUND FUNCTIONS
// ==========================================
brute_force_godmode()
{
    self endon("disconnect");
    self endon("stop_godmode");
    level endon("end_game");

    for(;;)
    {
        self.health = self.maxhealth;
        wait 0.05; 
    }
}

remove_quick_revive_limit()
{
    level endon("end_game");
    for(;;)
    {
        if ( isDefined( level.solo_lives_given ) ) { level.solo_lives_given = 0; }
        wait 1; 
    }
}

maintain_speed()
{
    self endon("disconnect");
    self endon("stop_speed_buff"); 
    level endon("end_game");

    for(;;)
    {
        if(self getMoveSpeedScale() < 1.5) { self setMoveSpeedScale(3); }
        wait 0.1; 
    }
}

// ==========================================
// UNIFIED MODERN HUD
// ==========================================

modern_counters_hud()
{
    self endon("disconnect");
    flag_wait("initial_blackscreen_passed");

    self.panel_bg = newClientHudElem(self);
    self.panel_bg.alignX = "left";
    self.panel_bg.alignY = "top";
    self.panel_bg.horzAlign = "user_left";
    self.panel_bg.vertAlign = "user_top";
    self.panel_bg.x = 5;
    self.panel_bg.y = 5;
    self.panel_bg setShader("white", 100, 52); 
    self.panel_bg.color = (0, 0, 0);
    self.panel_bg.alpha = 0.6;
    self.panel_bg.sort = 1;

    self.panel_line = newClientHudElem(self);
    self.panel_line.alignX = "left";
    self.panel_line.alignY = "top";
    self.panel_line.horzAlign = "user_left";
    self.panel_line.vertAlign = "user_top";
    self.panel_line.x = 5;
    self.panel_line.y = 5;
    self.panel_line setShader("white", 3, 52); 
    self.panel_line.color = (0, 0.6, 1);
    self.panel_line.alpha = 1;
    self.panel_line.sort = 2;

    self.zombie_text = newClientHudElem(self);
    self.zombie_text.alignX = "left";
    self.zombie_text.alignY = "top";
    self.zombie_text.horzAlign = "user_left";
    self.zombie_text.vertAlign = "user_top";
    self.zombie_text.x = 12;
    self.zombie_text.y = 8;
    self.zombie_text.fontscale = 1.2;
    self.zombie_text.color = (1, 1, 1);
    self.zombie_text.label = &"Zombies: ^5"; 
    self.zombie_text.sort = 3;

    self.round_time_text = newClientHudElem(self);
    self.round_time_text.alignX = "left";
    self.round_time_text.alignY = "top";
    self.round_time_text.horzAlign = "user_left";
    self.round_time_text.vertAlign = "user_top";
    self.round_time_text.x = 12;
    self.round_time_text.y = 23;
    self.round_time_text.fontscale = 1.2;
    self.round_time_text.color = (1, 1, 1);
    self.round_time_text.label = &"Round: ^5";
    self.round_time_text.sort = 3;

    self.game_time_text = newClientHudElem(self);
    self.game_time_text.alignX = "left";
    self.game_time_text.alignY = "top";
    self.game_time_text.horzAlign = "user_left";
    self.game_time_text.vertAlign = "user_top";
    self.game_time_text.x = 12;
    self.game_time_text.y = 38;
    self.game_time_text.fontscale = 1.2;
    self.game_time_text.color = (1, 1, 1);
    self.game_time_text.label = &"Game: ^5";
    self.game_time_text.sort = 3;

    self.game_time_text setTimerUp(0);
    self thread update_zombie_counter_modern();
    self thread update_round_timer_modern();
}

update_zombie_counter_modern()
{
    self endon("disconnect");
    for (;;)
    {
        self.zombie_text setvalue(level.zombie_total + get_current_zombie_count());
        wait 0.05;
    }
}

update_round_timer_modern()
{
    self endon("disconnect");
    for (;;)
    {
        self.round_time_text setTimerUp(0);
        start_time = GetTime() / 1000;
        level waittill("end_of_round");

        end_time = GetTime() / 1000;
        time_elapsed = end_time - start_time;

        self.round_time_text setTimer(time_elapsed);
    }
}

ezz_bars_hud()
{
    self endon("disconnect");
    flag_wait("initial_blackscreen_passed");

    bar_width = 130;
    hp_height = 8;
    shield_height = 3;  
    bg_padding = 4;
    y_bottom_anchor = -40; 

    self.hp_text = newClientHudElem(self);
    self.hp_text.alignX = "center";
    self.hp_text.alignY = "bottom";
    self.hp_text.horzAlign = "center";
    self.hp_text.vertAlign = "bottom";
    self.hp_text.x = 0;
    self.hp_text.y = y_bottom_anchor - hp_height - shield_height - bg_padding - 2; 
    self.hp_text.fontscale = 1.1;
    self.hp_text.label = &"^5HP / SHIELD";
    self.hp_text.sort = 2;

    self.hp_bg = newClientHudElem(self);
    self.hp_bg.alignX = "center";
    self.hp_bg.alignY = "bottom";
    self.hp_bg.horzAlign = "center";
    self.hp_bg.vertAlign = "bottom";
    self.hp_bg.x = 0;
    self.hp_bg.y = y_bottom_anchor;
    self.hp_bg setShader("white", bar_width + bg_padding, hp_height + shield_height + bg_padding);
    self.hp_bg.color = (0, 0, 0);
    self.hp_bg.alpha = 0.6;
    self.hp_bg.sort = 1;

    self.hp_bar = newClientHudElem(self);
    self.hp_bar.alignX = "left";
    self.hp_bar.alignY = "bottom";
    self.hp_bar.horzAlign = "center";
    self.hp_bar.vertAlign = "bottom";
    self.hp_bar.x = -(bar_width/2);
    self.hp_bar.y = y_bottom_anchor - (bg_padding/2); 
    self.hp_bar setShader("white", bar_width, hp_height);
    self.hp_bar.sort = 3;

    self.shield_bar = newClientHudElem(self);
    self.shield_bar.alignX = "left";
    self.shield_bar.alignY = "bottom";
    self.shield_bar.horzAlign = "center";
    self.shield_bar.vertAlign = "bottom";
    self.shield_bar.x = -(bar_width/2);
    self.shield_bar.y = y_bottom_anchor - (bg_padding/2) - hp_height; 
    self.shield_bar setShader("white", bar_width, shield_height);
    self.shield_bar.color = (0, 0.6, 1); 
    self.shield_bar.sort = 4;

    for(;;)
    {
        current_health = self.health;
        max_health = self.maxhealth;
        
        if(max_health <= 0) max_health = 100;
        health_percent = current_health / max_health;
        
        hp_visual_width = int(bar_width * health_percent);
        if(hp_visual_width < 1) hp_visual_width = 1; 

        if (health_percent >= 1.0) {
            self.hp_bar.color = (0, 1, 0); 
            self.hp_bar.alpha = 1;
        } else if (health_percent > 0.4) {
            self.hp_bar.color = (1, 1, 0); 
            self.hp_bar.alpha = 1;
        } else {
            self.hp_bar.color = (1, 0, 0); 
            self.hp_bar.alpha = (int(GetTime() / 250) % 2) ? 0.3 : 1; 
        }

        self.hp_bar setShader("white", hp_visual_width, hp_height);

        if ( self HasWeapon("riotshield_zm") || self HasWeapon("alcatraz_shield_zm") || self HasWeapon("tomb_shield_zm") )
        {
            self.shield_bar.alpha = 1;
        }
        else
        {
            self.shield_bar.alpha = 0;
        }

        wait 0.05; 
    }
}
