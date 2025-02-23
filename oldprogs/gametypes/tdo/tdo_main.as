/*
Copyright (C) 2009-2010 Chasseur de bots

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

const int CAPTURE_POINT_MAXVALUE = 3500; // 5 seconds touching to capture
const uint CAPTURE_POINT_SCORING_TIME = 5000; // 5 seconds captured earns a point
const int CAPTURE_POINT_CAPTURED_VALUE = ( 3 * CAPTURE_POINT_MAXVALUE * 0.25 );

const int CAPTURE_POINT_TIMER_DELAY = 250;

const int tdoSpawnableItems = 0;
const int tdoDropableItems = ( IT_AMMO | IT_POWERUP );

int TDO_RESPAWNWAVE_TIME = 20;
const int TDO_RESPAWNWAVE_MAXCOUNT = maxClients;

float TDO_HEALING_SCALE = 7.5f;
float TDO_MAX_ARMOR = 100.0f;
float TDO_MAX_HEALTH = 100.0f;

const int TDO_ROUNDSTATE_NONE = 0;
const int TDO_ROUNDSTATE_PREROUND = 1;
const int TDO_ROUNDSTATE_ROUND = 2;
const int TDO_ROUNDSTATE_ROUNDFINISHED = 3;
const int TDO_ROUNDSTATE_POSTROUND = 4;

class cTDORound
{
    int state;
    int numRounds;
    uint roundStateStartTime;
    uint roundStateEndTime;
    int countDown;

    cTDORound()
    {
        this.state = TDO_ROUNDSTATE_NONE;
        this.numRounds = 0;
        this.roundStateStartTime = 0;
        this.countDown = 0;
    }

    ~cTDORound() {}

    bool canTouchCapturePoint()
    {
        if ( this.state == TDO_ROUNDSTATE_ROUND )
            return true;

        if ( ( match.getState() <= MATCH_STATE_WARMUP ) && ( this.state == TDO_ROUNDSTATE_NONE ) )
            return true;

        return false;
    }

    void newGame()
    {
        gametype.readyAnnouncementEnabled = false;
        gametype.scoreAnnouncementEnabled = true;
        gametype.countdownEnabled = false;

        TDO_ResetCapturePoints();

        // set spawnsystem type to not respawn the players when they die
        for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
            gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_WAVES, TDO_RESPAWNWAVE_TIME, TDO_RESPAWNWAVE_MAXCOUNT, true );

        // clear scores

        Entity @ent;
        Team @team;
        int i;

        for ( i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
        {
            @team = @G_GetTeam( i );
            team.stats.clear();

            // respawn all clients inside the playing teams
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                ent.client.stats.clear(); // clear player scores & stats
            }
        }

        this.numRounds = 0;
        this.newRound();
    }

    void endGame()
    {
        this.newRoundState( TDO_ROUNDSTATE_NONE );
        GENERIC_SetUpEndMatch();
    }

    void newRound()
    {
        G_RemoveDeadBodies();
        G_RemoveAllProjectiles();

        this.newRoundState( TDO_ROUNDSTATE_PREROUND );
        this.numRounds++;
    }

    void newRoundState( int newState )
    {
        if ( newState > TDO_ROUNDSTATE_POSTROUND )
        {
            this.newRound();
            return;
        }

        this.state = newState;
        this.roundStateStartTime = levelTime;

        switch ( this.state )
        {
        case TDO_ROUNDSTATE_NONE:
            this.roundStateEndTime = 0;
            this.countDown = 0;
            break;

        case TDO_ROUNDSTATE_PREROUND:
        {
            TDO_ResetCapturePoints();
            G_RemoveAllProjectiles();
            G_Items_RespawnByType( 0, 0, 0 ); // remove all dropped items
            G_Items_RespawnByType( IT_POWERUP, 0, brandom( 60, 80 ) ); // delayed powerup respawn

            this.roundStateEndTime = levelTime + 7000;
            this.countDown = 5;

            // respawn everyone and disable shooting
            gametype.shootingDisabled = true;
            gametype.removeInactivePlayers = false;
            gametype.pickableItemsMask = 0; // disallow item pickup
            gametype.dropableItemsMask = 0; // disallow item drop

            Entity @ent;
            Team @team;

            for ( int i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
            {
                @team = @G_GetTeam( i );

                // respawn all clients inside the playing teams
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    ent.client.respawn( false );
                }
            }
        }
        break;

        case TDO_ROUNDSTATE_ROUND:
        {
            gametype.dropableItemsMask = tdoDropableItems;
            if ( gametype.isInstagib )
                gametype.dropableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);

            gametype.pickableItemsMask = ( gametype.spawnableItemsMask | gametype.dropableItemsMask );

            TDO_ResetCapturePoints();
            gametype.shootingDisabled = false;
            gametype.removeInactivePlayers = true;
            this.countDown = 0;
            this.roundStateEndTime = 0;
            int soundIndex = G_SoundIndex( "sounds/announcer/countdown/fight0" + (1 + (rand() & 1)) );
            G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
        }
        break;

        case TDO_ROUNDSTATE_ROUNDFINISHED:
            gametype.pickableItemsMask = 0; // disallow item pickup
            gametype.dropableItemsMask = 0; // disallow item drop
            gametype.shootingDisabled = true;
            this.roundStateEndTime = levelTime + 1500;
            this.countDown = 0;
            break;

        case TDO_ROUNDSTATE_POSTROUND:
        {
            this.roundStateEndTime = levelTime + 3000;

            // add score to round-winning team
            int count_alpha, count_beta;

            count_alpha = 0;
            count_beta = 0;

            for ( cCapturePoint @point = @cpHead; @point != null; @point = @point.next )
            {
                if ( point.owner.team == TEAM_ALPHA )
                    count_alpha++;
                if ( point.owner.team == TEAM_BETA )
                    count_beta++;
            }

            int soundIndex;

            if ( count_alpha > count_beta )
            {
                G_GetTeam( TEAM_ALPHA ).stats.addScore( 1 );
                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_team0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_ALPHA, false, null );
                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_enemy0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_BETA, false, null );

                Team @team = @G_GetTeam( TEAM_ALPHA );
                for ( int i = 0; @team.ent( i ) != null; i++ )
                {
                    if ( !team.ent( i ).isGhosting() )
                        team.ent( i ).client.addAward( S_COLOR_GREEN + "Victory!" );
                }
            }
            else if ( count_beta > count_alpha )
            {
                G_GetTeam( TEAM_BETA ).stats.addScore( 1 );
                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_team0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_BETA, false, null );
                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_enemy0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_ALPHA, false, null );

                Team @team = @G_GetTeam( TEAM_BETA );
                for ( int i = 0; @team.ent( i ) != null; i++ )
                {
                    if ( !team.ent( i ).isGhosting() )
                        team.ent( i ).client.addAward( S_COLOR_GREEN + "Victory!" );
                }
            }
            else // draw round
            {
                for ( int i = 0; i < maxClients; i++ )
                {
                    if ( !G_GetClient( i ).getEnt().isGhosting() )
                        G_GetClient( i ).addAward( S_COLOR_WHITE + "Draw Round!" );
                }
            }

            TDO_ResetCapturePoints();
        }
        break;

        default:
            break;
        }
    }

    void think()
    {
        float frac;

        if ( this.state == TDO_ROUNDSTATE_NONE )
            return;

        if ( match.getState() != MATCH_STATE_PLAYTIME )
        {
            this.endGame();
            return;
        }

        if ( this.roundStateEndTime != 0 )
        {
            if ( this.roundStateEndTime < levelTime )
            {
                this.newRoundState( this.state + 1 );
                return;
            }

            if ( this.countDown > 0 )
            {
                // we can't use the authomatic countdown announces because their are based on the
                // matchstate timelimit, and prerounds don't use it. So, fire the announces "by hand".
                int remainingSeconds = int( ( this.roundStateEndTime - levelTime ) * 0.001f ) + 1;
                if ( remainingSeconds < 0 )
                    remainingSeconds = 0;

                if ( remainingSeconds < this.countDown )
                {
                    this.countDown = remainingSeconds;

                    if ( this.countDown == 4 )
                    {
                        int soundIndex = G_SoundIndex( "sounds/announcer/countdown/ready0" + (1 + (rand() & 1)) );
                        G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
                    }
                    else if ( this.countDown <= 3 )
                    {
                        int soundIndex = G_SoundIndex( "sounds/announcer/countdown/" + this.countDown + "_0" + (1 + (rand() & 1)) );
                        G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
                    }
                }
            }
        }

        int count_alpha, count_beta, count_total;

        count_alpha = 0;
        count_beta = 0;
        count_total = 0;

        for ( cCapturePoint @point = @cpHead; @point != null; @point = @point.next )
        {
            count_total++;
            if ( point.owner.team == TEAM_ALPHA )
                count_alpha++;
            if ( point.owner.team == TEAM_BETA )
                count_beta++;
        }

        if ( count_total <= 0 )
            return;

        for ( int i = 0; i < maxClients; i++ )
        {
            Client @client = @G_GetClient( i );
            if ( client.state() < CS_SPAWNED )
                continue;

            frac = float( count_alpha ) / float( count_total );
            client.setHUDStat( STAT_PROGRESS_ALPHA, int( frac * 100 ) );

            frac = float( count_beta ) / float( count_total );
            client.setHUDStat( STAT_PROGRESS_BETA, int( frac * 100 ) );
        }

        // declare the round won when one of the team has all the points
        if ( this.state == TDO_ROUNDSTATE_ROUND )
        {
            if ( count_total == count_alpha || count_total == count_beta )
            {
                for ( int i = 0; i < maxClients; i++ )
                {
                    Client @client = @G_GetClient( i );

                    if ( !client.getEnt().isGhosting() )
                    {
                        if ( count_total == count_alpha && client.getEnt().team == TEAM_ALPHA )
                            client.addAward( S_COLOR_GREEN + "All Points Captured!" );

                        if ( count_total == count_beta && client.getEnt().team == TEAM_BETA )
                            client.addAward( S_COLOR_GREEN + "All Points Captured!" );
                    }
                }

                this.newRoundState( this.state + 1 );
            }
        }
    }
}

cTDORound tdoRound;

///*****************************************************************
/// LOCAL FUNCTIONS
///*****************************************************************

// a player has just died. The script is warned about it so it can account scores
void TDO_playerKilled( Entity @target, Entity @attacker, Entity @inflicter )
{
    if ( match.getState() != MATCH_STATE_PLAYTIME )
        return;

    if ( @target.client == null )
        return;

	playerSTAT_PROGRESS_SELFdelayed[ target.client.playerNum ] = 0;

    // update player score based on player stats

    target.client.stats.setScore( target.client.stats.frags - ( target.client.stats.suicides + target.client.stats.teamFrags ) );
    if ( @attacker != null && @attacker.client != null )
        attacker.client.stats.setScore( attacker.client.stats.frags - ( attacker.client.stats.suicides + attacker.client.stats.teamFrags ) );

    // drop items
    if ( ( G_PointContents( target.origin ) & CONTENTS_NODROP ) == 0 )
    {
        if ( target.client.inventoryCount( POWERUP_QUAD ) > 0 )
        {
            target.dropItem( POWERUP_QUAD );
            target.client.inventorySetCount( POWERUP_QUAD, 0 );
        }

        if ( target.client.inventoryCount( POWERUP_SHELL ) > 0 )
        {
            target.dropItem( POWERUP_SHELL );
            target.client.inventorySetCount( POWERUP_SHELL, 0 );
        }

        // drop ammo pack (won't drop anything if player doesn't have any ammo)
        target.dropItem( AMMO_PACK );
    }
}

///*****************************************************************
/// MODULE SCRIPT CALLS
///*****************************************************************

bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
    if ( cmdString == "drop" )
    {
        String token;

        for ( int i = 0; i < argc; i++ )
        {
            token = argsString.getToken( i );
            if ( token.len() == 0 )
                break;

            if ( token == "fullweapon" )
            {
                GENERIC_DropCurrentWeapon( client, true );
                GENERIC_DropCurrentAmmoStrong( client );
            }
            else if ( token == "weapon" )
            {
                GENERIC_DropCurrentWeapon( client, true );
            }
            else if ( token == "strong" )
            {
                GENERIC_DropCurrentAmmoStrong( client );
            }
            else
            {
                GENERIC_CommandDropItem( client, token );
            }
        }

        return true;
    }
    else if ( cmdString == "cvarinfo" )
    {
        GENERIC_CheatVarResponse( client, cmdString, argsString, argc );
        return true;
    }
    // example of registered command
    else if ( cmdString == "gametype" )
    {
        String response = "";
        Cvar fs_game( "fs_game", "", 0 );
        String manifest = gametype.manifest;

        response += "\n";
        response += "Gametype " + gametype.name + " : " + gametype.title + "\n";
        response += "----------------\n";
        response += "Version: " + gametype.version + "\n";
        response += "Author: " + gametype.author + "\n";
        response += "Mod: " + fs_game.string + (!manifest.empty() ? " (manifest: " + manifest + ")" : "") + "\n";
        response += "----------------\n";

        G_PrintMsg( client.getEnt(), response );
        return true;
    }
    else if ( cmdString == "callvotevalidate" )
    {
        String votename = argsString.getToken( 0 );
        if ( votename == "tdo_healing_scale" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            float value = voteArg.toFloat();
            if ( value == 0 && voteArg != "0" && voteArg != "0.0" )
            {
                client.printMessage( "Callvote " + votename + " expects a value as argument\n" );
                return false;
            }

            return true;
        }

        if ( votename == "tdo_respawn_time" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( value == 0 && voteArg != "0" && voteArg != "0.0" )
            {
                client.printMessage( "Callvote " + votename + " expects a value as argument\n" );
                return false;
            }

            if ( value < 5 )
            {
                client.printMessage( "Callvote " + votename + " does not accept respawn times shorter than 5 seconds\n" );
                return false;
            }

            if ( value > 120 )
            {
                client.printMessage( "Callvote " + votename + " does not accept respawn times larger than 120 seconds\n" );
                return false;
            }

            return true;
        }

        client.printMessage( "Unknown callvote " + votename + "\n" );
        return false;
    }
    else if ( cmdString == "callvotepassed" )
    {
        String votename = argsString.getToken( 0 );
        if ( votename == "tdo_healing_scale" )
        {
            TDO_HEALING_SCALE = argsString.getToken( 1 ).toFloat();
            if ( TDO_HEALING_SCALE < 0.0f )
                TDO_HEALING_SCALE = 0.0f;
        }
        else if ( votename == "tdo_respawn_time" )
        {
            TDO_RESPAWNWAVE_TIME = argsString.getToken( 1 ).toInt();
        }

        return true;
    }

    return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( Entity @ent )
{
    const float lowNeed = 0.5;
    Entity @goal;
    Bot @bot;
    float thisWeight;

    @bot = @ent.client.getBot();
    if ( @bot == null )
        return false;

    float offensiveStatus = GENERIC_OffensiveStatus( ent );

    for ( int i = AI::GetNextGoal( AI::GetRootGoal() ); i != AI::GetRootGoal(); i = AI::GetNextGoal( i ) )
    {
        @goal = @AI::GetGoalEntity( i );

        // by now, always full-ignore not solid entities
        if ( goal.solid == SOLID_NOT )
        {
            bot.setGoalWeight( i, 0 );
            continue;
        }

        if ( @goal.client != null )
        {
            bot.setGoalWeight( i, GENERIC_PlayerWeight( ent, goal ) * offensiveStatus );
            continue;
        }

        if ( @goal.item != null )
        {
            // all the following entities are items
            if ( ( goal.item.type & IT_WEAPON ) != 0 )
            {
                bot.setGoalWeight( i, GENERIC_WeaponWeight( ent, goal ) );
            }
            else if ( ( goal.item.type & IT_AMMO ) != 0 )
            {
                bot.setGoalWeight( i, GENERIC_AmmoWeight( ent, goal ) );
            }
            else if ( ( goal.item.type & IT_ARMOR ) != 0 )
            {
                bot.setGoalWeight( i, GENERIC_ArmorWeight( ent, goal ) );
            }
            else if ( ( goal.item.type & IT_HEALTH ) != 0 )
            {
                bot.setGoalWeight( i, GENERIC_HealthWeight( ent, goal ) );
            }
            else if ( ( goal.item.type & IT_POWERUP ) != 0 )
            {
                bot.setGoalWeight( i, bot.getItemWeight( goal.item ) * offensiveStatus );
            }

            continue;
        }

        // the entities spawned from scripts never have linked items,
        // so the capture points are weighted here

        cCapturePoint @point = @TDO_FindOwnedCapturePoint( goal );

        if ( @point != null && @point.owner != null )
        {
            if ( ent.team != goal.team )
            {
                if ( offensiveStatus >= 0.35f )
                    bot.setGoalWeight( i, 5 * offensiveStatus );
                else
                    bot.setGoalWeight( i, offensiveStatus );

                continue;
            }
        }

        // we don't know what entity is this, so ignore it
        bot.setGoalWeight( i, 0 );
    }

    return true; // handled by the script
}

// select a spawning point for a player
Entity @GT_SelectSpawnPoint( Entity @self )
{
    Entity @spawn;

    if ( self.team != TEAM_SPECTATOR )
    {
        gametype.spawnpointRadius = 512;
        @spawn = GENERIC_SelectBestRandomTeamSpawnPoint( self, "misc_capture_area_indicator", true );
    }

    gametype.spawnpointRadius = 256;
    if ( @spawn == null )
        @spawn = GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );

    return spawn;
}

String @GT_ScoreboardMessage( uint maxlen )
{
    String scoreboardMessage = "";
    String entry;
    Team @team;
    Entity @ent;
    int i, t;

    for ( t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
    {
        @team = @G_GetTeam( t );

        // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
        entry = "&t " + t + " " + team.stats.score + " " + team.ping + " ";
        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;

        for ( i = 0; @team.ent( i ) != null; i++ )
        {
            @ent = @team.ent( i );

            int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;

            // "Name Score Frags Ping R"
            entry = "&p " + playerID + " "
                    + ent.client.clanName + " "
                    + ent.client.stats.score + " "
                    + ent.client.stats.frags + " "
                    + ent.client.ping + " "
                    + ( ent.client.isReady() ? "1" : "0" ) + " ";

            if ( scoreboardMessage.len() + entry.len() < maxlen )
                scoreboardMessage += entry;
        }
    }

    return scoreboardMessage;
}

// Some game actions trigger score events. These are events not related to killing
// oponents, like capturing a flag
// Warning: client can be null
void GT_ScoreEvent( Client @client, const String &score_event, const String &args )
{
    if ( score_event == "dmg" )
    {
    }
    else if ( score_event == "kill" )
    {
        Entity @attacker = null;

        if ( @client != null )
            @attacker = @client.getEnt();

        int arg1 = args.getToken( 0 ).toInt();
        int arg2 = args.getToken( 1 ).toInt();

        // target, attacker, inflictor
        TDO_playerKilled( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );
    }
    else if ( score_event == "award" )
    {
    }
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
{
    if ( old_team != new_team )
    {
    }

    if ( ent.isGhosting() )
        return;

    if ( gametype.isInstagib )
    {
        ent.client.inventoryGiveItem( WEAP_INSTAGUN );
        ent.client.inventorySetCount( AMMO_INSTAS, 1 );
        ent.client.inventorySetCount( AMMO_WEAK_INSTAS, 1 );
    }
    else
    {
        Item @item;
        Item @ammoItem;

        // the gunblade can't be given (because it can't be dropped)
        ent.client.inventorySetCount( WEAP_GUNBLADE, 1 );

        @item = @G_GetItem( WEAP_GUNBLADE );

        // HACK for TDM: Don't let gunblades charge more than half the way
        @ammoItem = @G_GetItem( item.ammoTag );
        if ( @ammoItem != null )
            ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

        @ammoItem = item.weakAmmoTag == AMMO_NONE ? null : @G_GetItem( item.weakAmmoTag );
        if ( @ammoItem != null )
            ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

        for ( int i = WEAP_GUNBLADE + 1; i < WEAP_TOTAL; i++ )
        {
            if ( i == WEAP_INSTAGUN ) // dont add instagun...
                continue;

            ent.client.inventoryGiveItem( i );

            @item = @G_GetItem( i );

            @ammoItem = @G_GetItem( item.ammoTag );
            if ( @ammoItem != null )
                ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

            @ammoItem = item.weakAmmoTag == AMMO_NONE ? null : @G_GetItem( item.weakAmmoTag );
            if ( @ammoItem != null )
                ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );
        }

        // give him 100 armor
        ent.client.armor = TDO_MAX_ARMOR;
    }

    // auto-select best weapon in the inventory
    ent.client.selectWeapon( -1 );

    // add a teleportation effect
    ent.respawnEffect();
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
    if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished() )
    {
        if ( !match.checkExtendPlayTime() )
            match.launchState( match.getState() + 1 );
    }

    GENERIC_Think();

    if ( match.getState() >= MATCH_STATE_POSTMATCH )
        return;

    for ( int i = 0; i < maxClients; i++ )
    {
        GENERIC_ChargeGunblade( @G_GetClient( i ) );
    }

    // let capture points think
    for ( cCapturePoint @pointInfo = @cpHead; @pointInfo != null; @pointInfo = @pointInfo.next )
    {
        pointInfo.think();
    }

    tdoRound.think();

    for ( int i = 0; i < maxClients; i++ )
    {
        Client @client = @G_GetClient( i );
        if ( client.state() < CS_SPAWNED )
            continue;

        client.setHUDStat( STAT_PROGRESS_SELF, playerSTAT_PROGRESS_SELFdelayed[ client.playerNum ] );
		if( uint(playerLastTouched[ client.playerNum ] + CAPTURE_POINT_TIMER_DELAY) < levelTime )
			playerSTAT_PROGRESS_SELFdelayed[ client.playerNum ] = 0;
    }
}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
    if ( match.getState() <= MATCH_STATE_WARMUP && incomingMatchState > MATCH_STATE_WARMUP
            && incomingMatchState < MATCH_STATE_POSTMATCH )
        match.startAutorecord();

    if ( match.getState() == MATCH_STATE_POSTMATCH )
        match.stopAutorecord();

    return true;
}

void TDO_SetUpCountdown()
{
    gametype.shootingDisabled = true;
    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    G_RemoveAllProjectiles();

    TDO_ResetCapturePoints();

    gametype.pickableItemsMask = 0; // disallow item pickup
    gametype.dropableItemsMask = 0; // disallow item drop

    // lock teams
    bool anyone = false;
    if ( gametype.isTeamBased )
    {
        for ( int team = TEAM_ALPHA; team < GS_MAX_TEAMS; team++ )
        {
            if ( G_GetTeam( team ).lock() )
                anyone = true;
        }
    }
    else
    {
        if ( G_GetTeam( TEAM_PLAYERS ).lock() )
            anyone = true;
    }

    if ( anyone )
        G_PrintMsg( null, "Teams locked.\n" );

    // Countdowns should be made entirely client side, because we now can

    int soundIndex = G_SoundIndex( "sounds/announcer/countdown/get_ready_to_fight0" + (1 + (rand() & 1)) );
    G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
}

// the match state has just moved into a new state. Here is the
// place to set up the new state rules
void GT_MatchStateStarted()
{
    switch ( match.getState() )
    {
    case MATCH_STATE_WARMUP:
        gametype.dropableItemsMask = tdoDropableItems;
        if ( gametype.isInstagib )
            gametype.dropableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);

        gametype.pickableItemsMask = ( gametype.spawnableItemsMask | gametype.dropableItemsMask );

        TDO_ResetCapturePoints();
        GENERIC_SetUpWarmup();

        // set spawnsystem type to instant while players join
        for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
            gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );
        break;

    case MATCH_STATE_COUNTDOWN:
        TDO_SetUpCountdown();
        break;

    case MATCH_STATE_PLAYTIME:
        tdoRound.newGame();
        break;

    case MATCH_STATE_POSTMATCH:
        tdoRound.endGame();
        break;

    default:
        break;
    }
}

// the gametype is shutting down cause of a match restart or map change
void GT_Shutdown()
{
}

// The map entities have just been spawned. The level is initialized for
// playing, but nothing has yet started.
void GT_SpawnGametype()
{
}

// Important: This function is called before any entity is spawned, and
// spawning entities from it is forbidden. If you want to make any entity
// spawning at initialization do it in GT_SpawnGametype, which is called
// right after the map entities spawning.

void GT_InitGametype()
{
    gametype.title = "Team Domination";
    gametype.version = "1.14";
    gametype.author = "Warsow Development Team";

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.name + ".cfg" ) )
    {
        String config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.title + "' gametype configuration file\n"
                 + "// This config will be executed each time the gametype is started\n"
                 + "\n\n// map rotation\n"
                 + "set g_maplist \"wca1 wca3 wdm4 wdm7 wdm8 wdm9 wdm11 wdm13\" // list of maps in automatic rotation\n"
                 + "set g_maprotation \"1\"   // 0 = same map, 1 = in order, 2 = random\n"
                 + "\n// game settings\n"
                 + "set g_scorelimit \"7\"\n"
                 + "set g_timelimit \"0\"\n"
                 + "set g_warmup_timelimit \"1\"\n"
                 + "set g_match_extendedtime \"5\"\n"
                 + "set g_allow_falldamage \"0\"\n"
                 + "set g_allow_selfdamage \"0\"\n"
                 + "set g_allow_teamdamage \"0\"\n"
                 + "set g_allow_stun \"1\"\n"
                 + "set g_teams_maxplayers \"5\"\n"
                 + "set g_teams_allow_uneven \"0\"\n"
                 + "set g_countdown_time \"5\"\n"
                 + "set g_maxtimeouts \"3\" // -1 = unlimited\n"
                 + "\necho \"" + gametype.name + ".cfg executed\"\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.name + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.name + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.name + ".cfg silent" );
    }

    // let armors an powerups be spawned, because we may need something
    // to convert into capture points if the map hasn't any
    gametype.spawnableItemsMask = tdoSpawnableItems;
    gametype.dropableItemsMask = tdoDropableItems;

    if ( gametype.isInstagib )
    {
        gametype.spawnableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);
        gametype.dropableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);
    }

    gametype.respawnableItemsMask = gametype.spawnableItemsMask;
    gametype.pickableItemsMask = ( gametype.spawnableItemsMask | gametype.dropableItemsMask );

    gametype.isTeamBased = true;
    gametype.isRace = false;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 0;

    gametype.ammoRespawn = 20;
    gametype.armorRespawn = 25;
    gametype.weaponRespawn = 15;
    gametype.healthRespawn = 25;
    gametype.powerupRespawn = 90;
    gametype.megahealthRespawn = 20;
    gametype.ultrahealthRespawn = 60;

    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    gametype.mathAbortDisabled = false;
    gametype.shootingDisabled = false;
    gametype.infiniteAmmo = false;
    gametype.canForceModels = true;
    gametype.canShowMinimap = true;
    gametype.teamOnlyMinimap = true;
    gametype.removeInactivePlayers = true;

	gametype.mmCompatible = true;
	
    gametype.spawnpointRadius = 512;

    if ( gametype.isInstagib )
        gametype.spawnpointRadius *= 2;

    // set spawnsystem type
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );

    // define the scoreboard layout
    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 42 %i 40 %l 40 %r l1" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Frags Ping R" );

    // add commands
    G_RegisterCommand( "drop" );
    G_RegisterCommand( "gametype" );

    G_RegisterCallvote( "tdo_healing_scale", "<value>", "integer", "Sets the speed at which the capture points heal their owners" );
    G_RegisterCallvote( "tdo_respawn_time", "<value>", "integer", "Sets the time in seconds between reinforcement respawn waves" );

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}
