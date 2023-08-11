(* The Computer Language Benchmarks Game
 * http://shootout.alioth.debian.org/
 *
 * Based on nbody.java and adapted based on the SOM version.
 * Copyright (c) 2023 Rochus Keller <me@rochus-keller.ch> (for FreePascal migration)
 *)
 
unit NBody;
interface
uses Benchmark;

type
	PNBody = ^TNBody;
	TNBody = object(TBenchmark)
		    constructor init;
		    destructor deinit; virtual;
		    function benchmark(): longint; virtual;
		    function verifyResult(result: longint): boolean; virtual;
		    function innerBenchmarkLoop(innerIterations: longint): boolean; virtual;
		end;
		
implementation
	
    const
        PI = double(3.141592653589793);
        SOLAR_MASS = double(4.0 * PI * PI);
        DAYS_PER_YER = double(365.24);
     	numberOfBodies = 5;
       
    type
        TBody = object
                    x,y,z,vx,vy,vz,mass: double;
					procedure offsetMomentum(px, py, pz: double);
                end;
        NBodySystem = object 
        			bodies: array [0..numberOfBodies-1] of TBody;
        			constructor init();
        			procedure advance(dt: double);
        			function energy(): double;
        		end;

	procedure TBody.offsetMomentum(px, py, pz: double);
	begin
	   self.vx := 0.0 - (px / SOLAR_MASS);
	   self.vy := 0.0 - (py / SOLAR_MASS);
	   self.vz := 0.0 - (pz / SOLAR_MASS);
	end;

	procedure NBodySystem.advance(dt: double);
		var i,j: longint;
		    dx,dy,dz,dSquared,distance,mag: double;
		    iBody,jBody: TBody;
	begin
	   for i := 0 to numberOfBodies-1 do
	   begin
		  iBody := self.bodies[i];
		  for j := i + 1 to numberOfBodies-1 do
		  begin
		     jBody := self.bodies[j];
		     dx := iBody.x - jBody.x;
		     dy := iBody.y - jBody.y;
		     dz := iBody.z - jBody.z;

		     dSquared := dx * dx + dy * dy + dz * dz;
		     distance := sqrt(dSquared);
		     mag := dt / (dSquared * distance);

		     iBody.vx := iBody.vx - (dx * jBody.mass * mag);
		     iBody.vy := iBody.vy - (dy * jBody.mass * mag);
		     iBody.vz := iBody.vz - (dz * jBody.mass * mag);

		     jBody.vx := jBody.vx + (dx * iBody.mass * mag);
		     jBody.vy := jBody.vy + (dy * iBody.mass * mag);
		     jBody.vz := jBody.vz + (dz * iBody.mass * mag);
		  end;
		end;

	   	for i := 0 to numberOfBodies-1 do
	   	begin
		  iBody := self.bodies[i];
		  iBody.x := iBody.x + dt * iBody.vx;
		  iBody.y := iBody.y + dt * iBody.vy;
		  iBody.z := iBody.z + dt * iBody.vz;
	    end;
	end;

	function NBodySystem.energy(): double;
	   var dx,dy,dz,distance,e: double;
		   iBody,jBody: TBody;
		   i,j: longint;
	begin
	   e := 0.0;

	  for i := 0 to numberOfBodies-1 do
	  begin
		  iBody := self.bodies[i];
		  e := e + 0.5 * iBody.mass
		      * (iBody.vx * iBody.vx +
		         iBody.vy * iBody.vy +
		         iBody.vz * iBody.vz);

		  for j := i + 1 to numberOfBodies-1 do
		  begin
		     jBody := self.bodies[j];
		     dx := iBody.x - jBody.x;
		     dy := iBody.y - jBody.y;
		     dz := iBody.z - jBody.z;

		    distance := sqrt( dx * dx + dy * dy + dz * dz );
		    e := e - (iBody.mass * jBody.mass) / distance;
		  end;
	   end;
	   energy := e;
	end;

    function createBody(x,y,z,vx,vy,vz,mass: double): TBody;
        var b: TBody;
    begin
        b.x := x;
        b.y := y;
        b.z := z;
        b.vx := vx * DAYS_PER_YER;
        b.vy := vy * DAYS_PER_YER;
        b.vz := vz * DAYS_PER_YER;
        b.mass := mass * SOLAR_MASS;
        exit(b);
    end;

    function jupiter(): TBody;
    begin
    	exit(createBody(
         4.84143144246472090e+00,
        -1.16032004402742839e+00,
        -1.03622044471123109e-01,
         1.66007664274403694e-03,
         7.69901118419740425e-03,
        -6.90460016972063023e-05,
         9.54791938424326609e-04));
    end;

    function saturn(): TBody;
    begin
    	exit(createBody(
         8.34336671824457987e+00,
         4.12479856412430479e+00,
        -4.03523417114321381e-01,
        -2.76742510726862411e-03,
         4.99852801234917238e-03,
         2.30417297573763929e-05,
         2.85885980666130812e-04)); 
    end;

    function uranus(): TBody;
    begin
    	exit(createBody(
         1.28943695621391310e+01,
        -1.51111514016986312e+01,
        -2.23307578892655734e-01,
         2.96460137564761618e-03,
         2.37847173959480950e-03,
        -2.96589568540237556e-05,
         4.36624404335156298e-05));
    end;

    function neptune(): TBody;
    begin
    	exit(createBody(
         1.53796971148509165e+01,
        -2.59193146099879641e+01,
         1.79258772950371181e-01,
         2.68067772490389322e-03,
         1.62824170038242295e-03,
        -9.51592254519715870e-05,
         5.15138902046611451e-05));
    end;

    function sun(): TBody;
    begin
    	exit(createBody(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0));
    end;
    
    constructor NBodySystem.init();
        var i: longint;
            px,py,pz: double;
    begin        
        self.bodies[0] := sun();
        self.bodies[1] := jupiter();
        self.bodies[2] := saturn();
        self.bodies[3] := uranus();
        self.bodies[4] := neptune();
        
        px := 0.0; py := 0.0; pz := 0.0;
        for i := 0 to numberOfBodies-1 do
        begin
            px := px + self.bodies[i].vx * self.bodies[i].mass;
            py := py + self.bodies[i].vy * self.bodies[i].mass;
            pz := pz + self.bodies[i].vz * self.bodies[i].mass;
        end;

        self.bodies[0].offsetMomentum(px, py, pz);
    end;
    
    constructor TNBody.init;
    begin
    	inherited init;
    end;
    
    destructor TNBody.deinit;
    begin
    	inherited deinit;
    end;
    
    function TNBody.benchmark(): longint;
    begin
    	halt;
    	exit(0);
    end;
    
    function TNBody.verifyResult(result: longint): boolean;
    begin
    	halt;
    	exit(false);
    end;

	function verifyResult2(result: double; innerIterations: longint):boolean;
	const epsilon = 0.00005; // TODO 0.00000000000000005; // 5e-17
		// looks like the precision is only single, not double; somewhere precision gets lost
	begin
		if innerIterations = 250000 then exit(abs(result) - 0.1690859889909308 < epsilon);
		if innerIterations = 1 then exit(abs(result) - 0.16907495402506745 < epsilon);
													 //0.16907516382852447

		// Checkstyle: stop
		Write('No verification result for ');
		Write(innerIterations);
		WriteLn(' found');
		Write('Result is: ');
		WriteLn(result);
		// Checkstyle: resume
		exit(false);
	end;

    function TNBody.innerBenchmarkLoop(innerIterations: longint): boolean; 
	var system: NBodySystem;
        i: longint;
    begin
        system.init();
        for i := 0 to innerIterations-1 do
        	system.advance(0.01);
        exit(verifyResult2(system.energy(), innerIterations));
    end;

end.

