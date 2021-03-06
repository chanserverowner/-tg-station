/mob/living/simple_animal
	name = "animal"
	icon = 'icons/mob/animal.dmi'
	health = 20
	maxHealth = 20

	status_flags = CANPUSH

	var/icon_living = ""
	var/icon_dead = "" //icon when the animal is dead. Don't use animated icons for this.
	var/icon_gib = null	//We only try to show a gibbing animation if this exists.

	var/list/speak = list()
	var/list/speak_emote = list()//	Emotes while speaking IE: Ian [emote], [text] -- Ian barks, "WOOF!". Spoken text is generated from the speak variable.
	var/speak_chance = 0
	var/list/emote_hear = list()	//Hearable emotes
	var/list/emote_see = list()		//Unlike speak_emote, the list of things in this variable only show by themselves with no spoken text. IE: Ian barks, Ian yaps

	var/turns_per_move = 1
	var/turns_since_move = 0
	var/meat_amount = 0
	var/meat_type
	var/skin_type
	var/stop_automated_movement = 0 //Use this to temporarely stop random movement or to if you write special movement code for animals.
	var/wander = 1	// Does the mob wander around when idle?
	var/stop_automated_movement_when_pulled = 1 //When set to 1 this stops the animal from moving when someone is pulling it.

	//Interaction
	var/response_help   = "pokes"
	var/response_disarm = "shoves"
	var/response_harm   = "hits"
	var/harm_intent_damage = 3
	var/force_threshold = 0 //Minimum force required to deal any damage

	//Temperature effect
	var/minbodytemp = 250
	var/maxbodytemp = 350
	var/heat_damage_per_tick = 3	//amount of damage applied if animal's body temperature is higher than maxbodytemp
	var/cold_damage_per_tick = 2	//same as heat_damage_per_tick, only if the bodytemperature it's lower than minbodytemp

	//Atmos effect - Yes, you can make creatures that require plasma or co2 to survive. N2O is a trace gas and handled separately, hence why it isn't here. It'd be hard to add it. Hard and me don't mix (Yes, yes make all the dick jokes you want with that.) - Errorage
	var/list/atmos_requirements = list("min_oxy" = 5, "max_oxy" = 0, "min_tox" = 0, "max_tox" = 1, "min_co2" = 0, "max_co2" = 5, "min_n2" = 0, "max_n2" = 0) //Leaving something at 0 means it's off - has no maximum
	var/unsuitable_atmos_damage = 2	//This damage is taken when atmos doesn't fit all the requirements above

	//Healable by medical stacks? Defaults to yes.
	var/healable = 1


	//LETTING SIMPLE ANIMALS ATTACK? WHAT COULD GO WRONG. Defaults to zero so Ian can still be cuddly
	var/melee_damage_lower = 0
	var/melee_damage_upper = 0
	var/melee_damage_type = BRUTE //Damage type of a simple mob's melee attack, should it do damage.
	var/list/damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 1, CLONE = 1, STAMINA = 0, OXY = 1) // 1 for full damage , 0 for none , -1 for 1:1 heal from that source
	var/attacktext = "attacks"
	var/attack_sound = null
	var/friendly = "nuzzles" //If the mob does no damage with it's attack
	var/environment_smash = 0 //Set to 1 to allow breaking of crates,lockers,racks,tables; 2 for walls; 3 for Rwalls

	var/speed = 1 //LETS SEE IF I CAN SET SPEEDS FOR SIMPLE MOBS WITHOUT DESTROYING EVERYTHING. Higher speed is slower, negative speed is faster

	//Hot simple_animal baby making vars
	var/childtype = null
	var/scan_ready = 1
	var/species //Sorry, no spider+corgi buttbabies.

	var/supernatural = 0
	var/purge = 0
	var/flying = 0 //whether it's flying or touching the ground.
	var/del_on_death = 0
	var/list/loot = list() //list of things spawned at mob's loc when it dies
	var/deathmessage = ""
	var/death_sound = null //The sound played on death

	//simple_animal access
	var/obj/item/weapon/card/id/access_card = null	//innate access uses an internal ID card


/mob/living/simple_animal/New()
	..()
	verbs -= /mob/verb/observe
	if(!real_name)
		real_name = name

/mob/living/simple_animal/Login()
	if(src && src.client)
		src.client.screen = list()
		client.screen += client.void

	..()


/mob/living/simple_animal/updatehealth()
	..()
	health = Clamp(health, 0, maxHealth)
	if(health < 1 && stat != DEAD)
		death()

/mob/living/simple_animal/Life()
	if(..()) //alive
		if(!ckey && !key && !client)
			handle_automated_movement()
			handle_automated_action()
			handle_automated_speech()
		return 1

/mob/living/simple_animal/handle_regular_status_updates()
	if(..()) //alive
		if(health < 1 && stat != DEAD)
			death()
			return 0
		return 1

/mob/living/simple_animal/handle_disabilities()
	//Eyes
	if(disabilities & BLIND || stat)
		eye_blind = max(eye_blind, 1)
	else
		if(eye_blind)
			eye_blind = 0
		if(eye_blurry)
			eye_blurry = 0
		if(eye_stat)
			eye_stat = 0

	//Ears
	if(disabilities & DEAF)
		setEarDamage(-1, max(ear_deaf, 1))
	else if(ear_damage < 100)
		setEarDamage(0, 0)

/mob/living/simple_animal/handle_status_effects()
	..()
	if(stuttering)
		stuttering = 0

	if(druggy)
		druggy = 0

/mob/living/simple_animal/proc/handle_automated_action()
	return

/mob/living/simple_animal/proc/handle_automated_movement()
	if(!stop_automated_movement && wander)
		if(isturf(src.loc) && !resting && !buckled && canmove)		//This is so it only moves if it's not inside a closet, gentics machine, etc.
			turns_since_move++
			if(turns_since_move >= turns_per_move)
				if(!(stop_automated_movement_when_pulled && pulledby)) //Some animals don't move when pulled
					var/anydir = pick(cardinal)
					if(Process_Spacemove(anydir))
						Move(get_step(src, anydir), anydir)
						turns_since_move = 0
			return 1

/mob/living/simple_animal/proc/handle_automated_speech()
	if(speak_chance)
		if(rand(0,200) < speak_chance)
			if(speak && speak.len)
				if((emote_hear && emote_hear.len) || (emote_see && emote_see.len))
					var/length = speak.len
					if(emote_hear && emote_hear.len)
						length += emote_hear.len
					if(emote_see && emote_see.len)
						length += emote_see.len
					var/randomValue = rand(1,length)
					if(randomValue <= speak.len)
						say(pick(speak))
					else
						randomValue -= speak.len
						if(emote_see && randomValue <= emote_see.len)
							emote("me", 1, pick(emote_see))
						else
							emote("me", 2, pick(emote_hear))
				else
					say(pick(speak))
			else
				if(!(emote_hear && emote_hear.len) && (emote_see && emote_see.len))
					emote("me", 1, pick(emote_see))
				if((emote_hear && emote_hear.len) && !(emote_see && emote_see.len))
					emote("me", 2, pick(emote_hear))
				if((emote_hear && emote_hear.len) && (emote_see && emote_see.len))
					var/length = emote_hear.len + emote_see.len
					var/pick = rand(1,length)
					if(pick <= emote_see.len)
						emote("me", 1, pick(emote_see))
					else
						emote("me", 2, pick(emote_hear))


/mob/living/simple_animal/handle_environment(datum/gas_mixture/environment)
	var/atmos_suitable = 1

	var/atom/A = src.loc
	if(isturf(A))
		var/turf/T = A
		var/areatemp = get_temperature(environment)
		if( abs(areatemp - bodytemperature) > 40 )
			var/diff = areatemp - bodytemperature
			diff = diff / 5
			//world << "changed from [bodytemperature] by [diff] to [bodytemperature + diff]"
			bodytemperature += diff

		if(istype(T,/turf/simulated))
			var/turf/simulated/ST = T
			if(ST.air)
				var/tox = ST.air.toxins
				var/oxy = ST.air.oxygen
				var/n2  = ST.air.nitrogen
				var/co2 = ST.air.carbon_dioxide

				if(atmos_requirements["min_oxy"] && oxy < atmos_requirements["min_oxy"])
					atmos_suitable = 0
				else if(atmos_requirements["max_oxy"] && oxy > atmos_requirements["max_oxy"])
					atmos_suitable = 0
				else if(atmos_requirements["min_tox"] && tox < atmos_requirements["min_tox"])
					atmos_suitable = 0
				else if(atmos_requirements["max_tox"] && tox > atmos_requirements["max_tox"])
					atmos_suitable = 0
				else if(atmos_requirements["min_n2"] && n2 < atmos_requirements["min_n2"])
					atmos_suitable = 0
				else if(atmos_requirements["max_n2"] && n2 > atmos_requirements["max_n2"])
					atmos_suitable = 0
				else if(atmos_requirements["min_co2"] && co2 < atmos_requirements["min_co2"])
					atmos_suitable = 0
				else if(atmos_requirements["max_co2"] && co2 > atmos_requirements["max_co2"])
					atmos_suitable = 0

				if(!atmos_suitable)
					apply_damage(unsuitable_atmos_damage, OXY)

		else
			if(atmos_requirements["min_oxy"] || atmos_requirements["min_tox"] || atmos_requirements["min_n2"] || atmos_requirements["min_co2"])
				adjustBruteLoss(unsuitable_atmos_damage)

	handle_temperature_damage()

/mob/living/simple_animal/proc/handle_temperature_damage()
	if(bodytemperature < minbodytemp)
		apply_damage(2, BURN)
	else if(bodytemperature > maxbodytemp)
		apply_damage(3, BURN)


/mob/living/simple_animal/gib(var/animation = 0)
	if(icon_gib)
		flick(icon_gib, src)
	if(meat_amount && meat_type)
		for(var/i = 0; i < meat_amount; i++)
			new meat_type(src.loc)
	if(skin_type)
		new skin_type(src.loc)
	..()


/mob/living/simple_animal/blob_act()
	apply_damage(20, BRUTE)
	return

/mob/living/simple_animal/say_quote(input, list/spans)
	var/ending = copytext(input, length(input))
	if(speak_emote && speak_emote.len && ending != "?" && ending != "!")
		var/emote = pick(speak_emote)
		if(emote)
			input = attach_spans(input, spans)
			return "[emote], \"[input]\""
	return ..()

/mob/living/simple_animal/emote(var/act, var/m_type=1, var/message = null)
	if(stat)
		return
	if(act == "scream")
		message = "makes a loud and pained whimper" //ugly hack to stop animals screaming when crushed :P
		act = "me"
	..(act, m_type, message)

/mob/living/simple_animal/attack_animal(mob/living/simple_animal/M as mob)
	if(..())
		var/damage = rand(M.melee_damage_lower, M.melee_damage_upper)
		attack_threshold_check(damage)

/mob/living/simple_animal/bullet_act(var/obj/item/projectile/Proj)
	if(!Proj)
		return
	if((Proj.damage_type != STAMINA))
		apply_damage(Proj.damage, Proj.damage_type)
		Proj.on_hit(src, 0)
	return 0

/mob/living/simple_animal/proc/adjustHealth(amount)
	if(status_flags & GODMODE)
		return 0
	bruteloss = Clamp(bruteloss + amount, 0, maxHealth)
	updatehealth()
	return amount

/mob/living/simple_animal/adjustBruteLoss(amount)
	if(damage_coeff[BRUTE])
		. = adjustHealth(amount * damage_coeff[BRUTE])

/mob/living/simple_animal/adjustFireLoss(amount)
	if(damage_coeff[BURN])
		. = adjustHealth(amount * damage_coeff[BURN])

/mob/living/simple_animal/adjustOxyLoss(amount)
	if(damage_coeff[OXY])
		. = adjustHealth(amount * damage_coeff[OXY])

/mob/living/simple_animal/adjustToxLoss(amount)
	if(damage_coeff[TOX])
		. = adjustHealth(amount * damage_coeff[TOX])

/mob/living/simple_animal/adjustCloneLoss(amount)
	if(damage_coeff[CLONE])
		. = adjustHealth(amount * damage_coeff[CLONE])
/mob/living/simple_animal/adjustStaminaLoss(amount)
	return

/mob/living/simple_animal/attack_hand(mob/living/carbon/human/M as mob)
	switch(M.a_intent)

		if("help")
			if (health > 0)
				visible_message("<span class='notice'>[M] [response_help] [src].</span>")
				playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)

		if("grab")
			grabbedby(M)

		if("harm", "disarm")
			M.do_attack_animation(src)
			visible_message("<span class='danger'>[M] [response_harm] [src]!</span>")
			playsound(loc, "punch", 25, 1, -1)
			attack_threshold_check(harm_intent_damage)
			add_logs(M, src, "attacked", admin=0)
			updatehealth()
	return

/mob/living/simple_animal/attack_paw(mob/living/carbon/monkey/M as mob)
	if(..()) //successful monkey bite.
		if(stat != DEAD)
			var/damage = rand(1, 3)
			attack_threshold_check(damage)
	if (M.a_intent == "help")
		if (health > 0)
			visible_message("<span class='notice'>[M.name] [response_help] [src].</span>")
			playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)

	return

/mob/living/simple_animal/attack_alien(mob/living/carbon/alien/humanoid/M as mob)
	if(..()) //if harm or disarm intent.
		var/damage = rand(15, 30)
		visible_message("<span class='danger'>[M] has slashed at [src]!</span>", \
				"<span class='userdanger'>[M] has slashed at [src]!</span>")
		playsound(loc, 'sound/weapons/slice.ogg', 25, 1, -1)
		add_logs(M, src, "attacked", admin=0)
		attack_threshold_check(damage)
	return

/mob/living/simple_animal/attack_larva(mob/living/carbon/alien/larva/L as mob)
	if(..()) //successful larva bite
		var/damage = rand(5, 10)
		if(stat != DEAD)
			L.amount_grown = min(L.amount_grown + damage, L.max_grown)
			attack_threshold_check(damage)

/mob/living/simple_animal/attack_slime(mob/living/carbon/slime/M as mob)
	..()
	var/damage = rand(1, 3)

	if(M.is_adult)
		damage = rand(20, 40)
	else
		damage = rand(5, 35)
	attack_threshold_check(damage)
	return

/mob/living/simple_animal/proc/attack_threshold_check(var/damage)
	if(damage <= force_threshold)
		visible_message("<span class='warning'>[src] looks unharmed.</span>")
	else
		adjustBruteLoss(damage)
		updatehealth()


/mob/living/simple_animal/attackby(var/obj/item/O as obj, var/mob/living/user as mob, params) //Marker -Agouri
	if(O.flags & NOBLUDGEON)
		return

	user.changeNext_move(CLICK_CD_MELEE)

	if(istype(O, /obj/item/stack/medical))
		if(stat != DEAD)
			var/obj/item/stack/medical/MED = O
			if(healable && health < maxHealth)
				if(MED.amount >= 1)
					if(MED.heal_brute >= 1)
						adjustBruteLoss(-MED.heal_brute)
						MED.amount -= 1
						if(MED.amount <= 0)
							qdel(MED)
						visible_message("<span class='notice'> [user] applies [MED] on [src].</span>")
						return
					else
						user << "<span class='notice'> [MED] won't help at all.</span>"
						return
			else
				user << "<span class='notice'> [src] is at full health.</span>"
				return
		else
			user << "<span class='notice'> [src] is dead, medical items won't bring it back to life.</span>"
			return

	if((meat_type || skin_type) && (stat == DEAD))	//if the animal has a meat, and if it is dead.
		var/sharpness = is_sharp(O)
		if(sharpness)
			harvest(user, sharpness)
			return

	user.do_attack_animation(src)
	var/damage = 0
	if(O.force)
		if(O.force >= force_threshold)
			damage = O.force
			if (O.damtype == STAMINA)
				damage = 0
			if(O.attack_verb && islist(O.attack_verb))
				visible_message("<span class='danger'>[user] has [O.attack_verb.len ? "[pick(O.attack_verb)]": "attacked"] [src] with [O]!</span>",\
								"<span class='userdanger'>[user] has [O.attack_verb.len ? "[pick(O.attack_verb)]": "attacked"] you with [O]!</span>")
			else
				visible_message("<span class='danger'>[user] has attacked [src] with [O]!</span>",\
								"<span class='userdanger'>[user] has attacked you with [O]!</span>")

		else
			visible_message("<span class='danger'>[O] bounces harmlessly off of [src].</span>",\
							"<span class='userdanger'>[O] bounces harmlessly off of [src].</span>")
		playsound(loc, O.hitsound, 50, 1, -1)
	else
		user.visible_message("<span class='warning'>[user] gently taps [src] with [O].</span>",\
							"<span class='warning'>This weapon is ineffective, it does no damage.</span>")
	adjustBruteLoss(damage)

/mob/living/simple_animal/movement_delay()
	var/tally = 0 //Incase I need to add stuff other than "speed" later

	tally = speed

	return tally+config.animal_delay

/mob/living/simple_animal/Stat()
	..()

	if(statpanel("Status"))
		stat(null, "Health: [round((health / maxHealth) * 100)]%")

/mob/living/simple_animal/death(gibbed)
	if(loot.len)
		for(var/i in loot)
			new i(loc)
	if(!gibbed)
		if(death_sound)
			playsound(get_turf(src),death_sound, 200, 1)
		if(deathmessage)
			visible_message("<span class='danger'>\The [src] [deathmessage]</span>")
		else if(!del_on_death)
			visible_message("<span class='danger'>\The [src] stops moving...</span>")
	if(del_on_death)
		ghostize()
		qdel(src)
	else
		health = 0
		icon_state = icon_dead
		stat = DEAD
		lying = 1
		density = 0


	..()

/mob/living/simple_animal/ex_act(severity, target)
	..()
	switch (severity)
		if (1.0)
			gib()
			return

		if (2.0)
			adjustBruteLoss(60)


		if(3.0)
			adjustBruteLoss(30)

/mob/living/simple_animal/proc/CanAttack(var/atom/the_target)
	if(see_invisible < the_target.invisibility)
		return 0
	if (isliving(the_target))
		var/mob/living/L = the_target
		if(L.stat != CONSCIOUS)
			return 0
	if (istype(the_target, /obj/mecha))
		var/obj/mecha/M = the_target
		if (M.occupant)
			return 0
	return 1


/mob/living/simple_animal/update_fire()
	return
/mob/living/simple_animal/IgniteMob()
	return
/mob/living/simple_animal/ExtinguishMob()
	return

/mob/living/simple_animal/revive()
	health = maxHealth
	icon_state = icon_living
	density = initial(density)
	update_canmove()
	..()

/mob/living/simple_animal/proc/make_babies() // <3 <3 <3
	if(gender != FEMALE || stat || !scan_ready || !childtype || !species)
		return
	scan_ready = 0
	spawn(400)
		scan_ready = 1
	var/alone = 1
	var/mob/living/simple_animal/partner
	var/children = 0
	for(var/mob/M in oview(7, src))
		if(M.stat != CONSCIOUS) //Check if it's concious FIRSTER.
			continue
		else if(istype(M, childtype)) //Check for children FIRST.
			children++
		else if(istype(M, species))
			if(M.ckey)
				continue
			else if(!istype(M, childtype) && M.gender == MALE) //Better safe than sorry ;_;
				partner = M
		else if(istype(M, /mob/))
			alone = 0
			continue
	if(alone && partner && children < 3)
		new childtype(loc)

// Harvest an animal's delicious byproducts
/mob/living/simple_animal/proc/harvest(mob/living/user, sharpness = 1)
	user << "<span class='notice'>You begin to butcher [src].</span>"
	playsound(loc, 'sound/weapons/slice.ogg', 50, 1, -1)
	if(do_mob(user, src, 80/sharpness))
		visible_message("<span class='notice'>[user] butchers [src].</span>")
		gib()
	return

/mob/living/simple_animal/stripPanelUnequip(obj/item/what, mob/who, where, child_override)
	if(!child_override)
		src << "<span class='warning'>You don't have the dexterity to do this!</span>"
		return
	else
		..()

/mob/living/simple_animal/stripPanelEquip(obj/item/what, mob/who, where, child_override)
	if(!child_override)
		src << "<span class='warning'>You don't have the dexterity to do this!</span>"
		return
	else
		..()


/mob/living/simple_animal/update_canmove()
	canmove = ..()
	density = initial(density) & !lying // 0 density if it's not dense or if it's dead
	return canmove

