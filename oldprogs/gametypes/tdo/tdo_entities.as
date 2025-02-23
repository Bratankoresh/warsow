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

cCapturePoint @cpHead = null;

int[] playerSTAT_PROGRESS_SELFdelayed( maxClients );
uint[] playerLastTouched( maxClients );

class cCapturePoint
{
    int teamSlide;
    int pointID; // a, b, c, d
    uint lastTouched;
    uint spawnTimeStamp;
    uint scoreTimeStamp;
    cCapturePoint @next;
    Entity @owner;
    Entity @model;
    Entity @sprite;
    Entity @minimap;
	int locationTag;

    void Initialize( Entity @ent )
    {
        if ( @cpHead == null )
            this.pointID = 0;
        else
            this.pointID = cpHead.pointID + 1;

		this.locationTag = -2; // G_LocationTag can return -1, so to avoid double checks the default value is -2
        this.teamSlide = 0;
        this.lastTouched = 0;
        this.spawnTimeStamp = levelTime;
        this.scoreTimeStamp = levelTime;
        @this.next = @cpHead;
        @cpHead = @this;

        @this.owner = @ent;

        // the active entity is kept invisible and never sent to the client
        this.owner.modelindex = 0;
        this.owner.solid = SOLID_TRIGGER;
        this.owner.nextThink = levelTime + 1000;
        AI::AddGoal( this.owner, true ); // bases are special because of the timers, use custom reachability checks
        this.owner.team = 0;
        this.owner.linkEntity();

        // the model entity is moved upwards to have it floating above players
        Vec3 vec = this.owner.origin;
        vec.z += 128;

        @this.model = @G_SpawnEntity( "capture_indicator_model" );
        this.model.type = ET_GENERIC;
        this.model.solid = SOLID_NOT;
        this.model.origin = vec;
        this.model.origin2 = vec;
        this.model.setupModel( "models/objects/capture_area/indicator.md3" );
        this.model.svflags &= ~uint(SVF_NOCLIENT);
        this.model.effects = EF_ROTATE_AND_BOB;
        this.model.linkEntity();

        // the sprite entity is also placed upwards and sent as broadcast
        @this.sprite = @G_SpawnEntity( "capture_indicator_sprite" );
        this.sprite.type = ET_RADAR;
        this.sprite.solid = SOLID_NOT;
        this.sprite.origin = vec;
        this.sprite.origin2 = vec;
        this.sprite.modelindex = G_ImageIndex( "gfx/indicators/radar" );
        this.sprite.frame = 132; // radius in case of a ET_SPRITE
        this.sprite.svflags = (this.sprite.svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST);
        this.sprite.linkEntity();

        // another entity to represent it in the minimap
        @this.minimap = @G_SpawnEntity( "capture_indicator_minimap" );
        this.minimap.type = ET_MINIMAP_ICON;
        this.minimap.solid = SOLID_NOT;
        this.minimap.origin = vec;
        this.minimap.origin2 = vec;
        this.minimap.modelindex = G_ImageIndex( "gfx/indicators/radar_1" );
        this.minimap.frame = 32; // size in case of a ET_MINIMAP_ICON
        this.minimap.svflags = (this.minimap.svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST);
        this.minimap.linkEntity();
    }

    cCapturePoint()
    {
        Initialize( null );
    }

    cCapturePoint( Entity @owner )
    {
        Initialize( owner );
    }

    ~cCapturePoint()
    {
    }

    void reset()
    {
        this.teamSlide = 0;
        this.owner.team = 0;
        this.lastTouched = 0;
        this.owner.team = 0;
        this.scoreTimeStamp = levelTime;
    }

    void use( Entity @activator )
    {
        Team @team;

        if ( tdoRound.canTouchCapturePoint() == false )
            return;

        if ( @this.owner == null )
            return;

        if ( @activator.client == null )
            return;

        this.lastTouched = levelTime;
		playerLastTouched[ activator.client.playerNum ] = levelTime;

        if ( activator.team == TEAM_ALPHA )
            this.teamSlide -= frameTime;
        else if ( activator.team == TEAM_BETA )
            this.teamSlide += frameTime;
        else
            return;

        if ( this.teamSlide > CAPTURE_POINT_MAXVALUE )
            this.teamSlide = CAPTURE_POINT_MAXVALUE;
        else if ( this.teamSlide < -CAPTURE_POINT_MAXVALUE )
            this.teamSlide = -CAPTURE_POINT_MAXVALUE;

        int alpha = 0, beta = 0;

        if ( this.teamSlide < 0 )
            alpha = -this.teamSlide;
        else if ( this.teamSlide > 0 )
            beta = this.teamSlide;

		if( this.locationTag == -2 )
			this.locationTag = G_LocationTag( G_LocationName( this.model.origin ) );
		String locationStr;

        // see if it's captured by any team
        if ( alpha > CAPTURE_POINT_CAPTURED_VALUE )
        {
			locationStr = (this.locationTag > 0 ? " @ " + G_LocationName( this.locationTag ) + S_COLOR_GREEN : "");

            if ( this.owner.team != TEAM_ALPHA )
            {
                @team = @G_GetTeam( TEAM_ALPHA );
                for ( int i = 0; @team.ent( i ) != null; i++ )
                {
                    if ( !team.ent( i ).isGhosting() )
                        team.ent( i ).client.addAward( S_COLOR_GREEN + "Point" + locationStr + " Captured!" );
                }

                AI::ReachedGoal( this.owner ); // let bots know their mission was completed
            }

            this.owner.team = TEAM_ALPHA;
        }
        else if ( beta > CAPTURE_POINT_CAPTURED_VALUE )
        {
            if ( this.owner.team != TEAM_BETA )
            {
                @team = @G_GetTeam( TEAM_BETA );
                for ( int i = 0; @team.ent( i ) != null; i++ )
                {
                    if ( !team.ent( i ).isGhosting() )
                        team.ent( i ).client.addAward( S_COLOR_GREEN + "Point" + locationStr + " Captured!" );
                }

                AI::ReachedGoal( this.owner ); // let bots know their mission was completed
            }

            this.owner.team = TEAM_BETA;
        }
        else
        {
			locationStr = (this.locationTag > 0 ? " @ " + G_LocationName( this.locationTag ) + S_COLOR_RED : "");

            if ( this.owner.team == TEAM_ALPHA )
            {
                @team = @G_GetTeam( TEAM_ALPHA );
                for ( int i = 0; @team.ent( i ) != null; i++ )
                {
                    if ( !team.ent( i ).isGhosting() )
                        team.ent( i ).client.addAward( S_COLOR_RED + "Point" + locationStr + " Lost!" );
                }
            }
            if ( this.owner.team == TEAM_BETA )
            {
                @team = @G_GetTeam( TEAM_BETA );
                for ( int i = 0; @team.ent( i ) != null; i++ )
                {
                    if ( !team.ent( i ).isGhosting() )
                        team.ent( i ).client.addAward( S_COLOR_RED + "Point" + locationStr + " Lost!" );
                }
            }

            this.owner.team = 0;
        }

        // give health to players in posession of the spot

        if ( this.owner.team == activator.team && @activator.client != null )
        {
            activator.health += ( frameTime * 0.001 * TDO_HEALING_SCALE );
            if ( activator.health > TDO_MAX_HEALTH )
                activator.health = TDO_MAX_HEALTH;

            activator.client.armor += ( frameTime * 0.001 * TDO_HEALING_SCALE );
            if ( activator.client.armor > TDO_MAX_ARMOR )
                activator.client.armor = TDO_MAX_ARMOR;
        }

        // let the players touching a spot know how the load is going
        float frac = float( this.teamSlide ) / float( CAPTURE_POINT_MAXVALUE );
        if ( frac < -1 )
            frac = -1;
        if ( frac > 1 )
            frac = 1;

        if ( frac > -1.0f && frac < 1.0f )
        {
            //if ( activator.team == TEAM_ALPHA )
            //    activator.client.setHUDStat( STAT_PROGRESS_SELF, -int( frac * 100 ) );
            //else
            //    activator.client.setHUDStat( STAT_PROGRESS_SELF, int( frac * 100 ) );
            if ( activator.team == TEAM_ALPHA )
				playerSTAT_PROGRESS_SELFdelayed[ activator.client.playerNum ] = -int( frac * 100 );
			else
				playerSTAT_PROGRESS_SELFdelayed[ activator.client.playerNum ] = int( frac * 100 );
        }
		else
		{
			playerSTAT_PROGRESS_SELFdelayed[ activator.client.playerNum ] = 0;
		}
    }

    void think()
    {
        if ( @this.owner == null  )
            return;

        // set up the color effects on the indicators
        this.model.effects &= ~uint(EF_TEAMCOLOR_TRANSITION);
        this.sprite.effects &= ~uint(EF_TEAMCOLOR_TRANSITION);
        this.model.counterNum = this.sprite.counterNum = this.minimap.counterNum = 0;
        this.model.team = this.sprite.team = this.minimap.team = this.owner.team;

        // if not completely captured set up the color transition
        if ( this.owner.team == 0 )
        {
            int slide = 0;

            if ( this.teamSlide < 0 ) // TEAM_ALPHA side
            {
                this.model.team = TEAM_ALPHA;
                this.model.effects |= EF_TEAMCOLOR_TRANSITION;
                this.sprite.team = TEAM_ALPHA;
                this.sprite.effects |= EF_TEAMCOLOR_TRANSITION;
                this.minimap.team = this.sprite.team;
                this.minimap.effects = this.sprite.effects;

                slide = -this.teamSlide;
            }
            else if ( this.teamSlide > 0 ) // TEAM_BETA side
            {
                this.model.team = TEAM_BETA;
                this.model.effects |= EF_TEAMCOLOR_TRANSITION;
                this.sprite.team = TEAM_BETA;
                this.sprite.effects |= EF_TEAMCOLOR_TRANSITION;
                this.minimap.team = this.sprite.team;
                this.minimap.effects = this.sprite.effects;

                slide = this.teamSlide;
            }

            if ( slide != 0 )
            {
                float frac = float( slide ) / float( CAPTURE_POINT_CAPTURED_VALUE );
                if ( frac < 0 )
                    frac = 0;
                if ( frac > 1 )
                    frac = 1;

                this.model.counterNum = int( frac * 255 );
                this.sprite.counterNum = int( frac * 255 );
                this.minimap.counterNum = int( frac * 255 );
            }
        }

        // if the point wasn't touched this frame, and it's not
        // captured but it has some team value, go loosing it
        if ( uint(this.lastTouched + CAPTURE_POINT_TIMER_DELAY) <= levelTime )
        {
            if ( this.owner.team == TEAM_ALPHA )
            {
                if ( this.teamSlide - frameTime >= -CAPTURE_POINT_MAXVALUE )
                    this.teamSlide -= frameTime;
                else
                    this.teamSlide = -CAPTURE_POINT_MAXVALUE;
            }
            else if ( this.owner.team == TEAM_BETA )
            {
                if ( this.teamSlide + frameTime <= CAPTURE_POINT_MAXVALUE )
                    this.teamSlide += frameTime;
                else
                    this.teamSlide = CAPTURE_POINT_MAXVALUE;
            }
            else
            {
                if ( this.teamSlide > 0 )
                {
                    if ( this.teamSlide >= int(frameTime) )
                        this.teamSlide -= frameTime;
                    else
                        this.teamSlide = 0;
                }
                else if ( this.teamSlide < 0 )
                {
                    if ( this.teamSlide <= -int(frameTime) )
                        this.teamSlide += int(frameTime);
                    else
                        this.teamSlide = 0;
                }
            }
        }
    }
}

cCapturePoint @TDO_FindOwnedCapturePoint( Entity @ent )
{
    for ( cCapturePoint @point = @cpHead; @point != null; @point = @point.next )
    {
        if ( @point.owner == @ent )
            return point;
    }

    return null;
}

void TDO_ResetCapturePoints()
{
    for ( cCapturePoint @point = @cpHead; @point != null; @point = @point.next )
        point.reset();
	
	for ( int i = 0; i < maxClients; i++ )
		playerLastTouched[i] = 0;
}

///*****************************************************************
/// NEW MAP ENTITY DEFINITIONS
///*****************************************************************

void misc_capture_area_indicator_use( Entity @ent, Entity @other, Entity @activator )
{
    if ( @activator == null || @activator.client == null )
        return;

    cCapturePoint @pointInfo = @TDO_FindOwnedCapturePoint( ent );
    if ( @pointInfo == null )
        return; // not found

    pointInfo.use( activator );
}

void misc_capture_area_indicator_think( Entity @ent )
{
    float radius = 300;

    ent.nextThink = levelTime + 1;

    if ( tdoRound.canTouchCapturePoint() == false )
        return;

    // see if the point is targeted elsewhere
    array<Entity @> @triggers = @ent.findTargeting();
    if ( !triggers.empty() )
        return; // it's handled by the trigger touch function

    // it's not triggered, so do a search of players around the point

    // find players around
    Trace tr;
    Vec3 center, mins, maxs, origin, sourcePoint;
    Entity @target = G_GetEntity( 0 ); // world
	Entity @stop = G_GetClient( maxClients - 1 ).getEnt(); // the last entity to be checked

    origin = ent.origin;
    sourcePoint = origin;
    sourcePoint.z += 96;

	array<Entity @> @inradius = G_FindInRadius( sourcePoint, radius );
    for( uint i = 0; i < inradius.size(); i++ )
	{
        @target = inradius[i];
		if( @target.client == null )
			continue;	

        if ( target.client.state() < CS_SPAWNED )
            continue;

        if ( target.isGhosting() )
            continue;

        // check if the player is visible from the indicator
        target.getSize( mins, maxs );
        center = target.origin;

        // don't allow captures from below
        Vec3 upper = center + maxs;
        if ( upper.z < origin.z + 16 )
            continue;

        center += 0.5 * ( maxs + mins );
        mins = maxs = 0;

        if ( !tr.doTrace( sourcePoint, mins, maxs, center, target.entNum, MASK_SOLID ) )
        {
            ent.use( ent, ent, target );
        }
    }
}

// set up the capture area point
void misc_capture_area_indicator( Entity @ent )
{
	@ent.use = misc_capture_area_indicator_use;
	@ent.think = misc_capture_area_indicator_think;

    // drop to floor
    if ( ( ent.spawnFlags & 1 ) == 0 )
    {
        Trace tr;
        Vec3 end, start, mins( -16, -16, -24 ), maxs( 16, 16, 32 );

        start = end = ent.origin;
        start.z += 16;
        end.z -= 512;

        // check for starting inside solid
        tr.doTrace( start, mins, maxs, start, ent.entNum, MASK_DEADSOLID );
        if ( tr.startSolid || tr.allSolid )
        {
            G_Print( ent.classname + " starts inside solid. Inhibited\n" );
            ent.freeEntity();
            return;
        }

        if ( tr.doTrace( start, mins, maxs, end, ent.entNum, MASK_DEADSOLID ) )
        {
            ent.origin = tr.endPos;
            ent.origin2 = tr.endPos;
        }
    }

    // spawn a local holder for capturing time information
    cCapturePoint thisPoint( ent );
}

// "void %s_touch( Entity @ent, Entity @other, const Vec3 planeNormal, int surfFlags )"
void trigger_capture_area_touch( Entity @ent, Entity @other, const Vec3 planeNormal, int surfFlags )
{
    if ( @other.client == null )
        return;

    // find the indicator linked to the trigger.
	array<Entity @> @targets = ent.findTargets();
    for( uint i = 0; i < targets.size(); i++ )
    {
        Entity @indicator = targets[i];
        indicator.use( indicator, indicator, other );
    }
}

// if it doesn't have a target, free it. Never think again after this
void trigger_capture_area_think( Entity @ent )
{
	array<Entity @> @targets = ent.findTargets();
	if( !targets.empty() )
		return;

    G_Print( "trigger_capture_area without an indicator. Removing\n" );
    ent.freeEntity();
}

// set up the trigger
void trigger_capture_area( Entity @ent )
{
	@ent.think = trigger_capture_area_think;
	@ent.touch = trigger_capture_area_touch;
    ent.setupModel( ent.model ); // set up the brush model
    ent.solid = SOLID_TRIGGER;
    ent.linkEntity();
	ent.wait = 0;

    // add a check to free the trigger if it isn't targeting a capture area
    ent.nextThink = levelTime + 1;
}
