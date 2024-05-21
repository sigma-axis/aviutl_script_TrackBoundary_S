--[[
MIT License
Copyright (c) 2024 sigma-axis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

https://mit-license.org/
]]

--
-- VERSION: v1.01
--

--------------------------------

-- check fo LuaJIT.
if not jit then
	local function show_info()
		obj.setfont("MS UI Gothic",34);
		obj.load("text","LuaJIT が必要です！");
	end
	return setmetatable({}, { __index = function(...) return show_info end });
end

-- localized globals.
local ffi = require"ffi";
local math,obj = math,obj;
local math_min,math_max=math.min,math.max;
local bit_band=bit.band;

-- determines whether the pixel is to be filled.
local function is_opaque(buf,I, thresh) return buf[4*I]>thresh end
local function is_transparent(buf,I, thresh) return not is_opaque(buf,I, thresh) end
local function color_similar(buf,I, thresh, r_m,g_m,b_m,r_M,g_M,b_M)
	return r_m <= buf[0+4*I] and buf[0+4*I] <= r_M
		and g_m <= buf[1+4*I] and buf[1+4*I] <= g_M
		and b_m <= buf[2+4*I] and buf[2+4*I] <= b_M
		and buf[3+4*I] > thresh;
end

-- `dir` shall mean as, for each targeted pixel,
-- a boundary path lies on and goes to the direction as the followings:
--   0 -> left edge upward,    1 -> top edge toward right,
--   2 -> right edge downward, 3 -> bottom edge toward left.
-- figured as below:
--       1→
--     0↑□↓2
--       3←
-- □ represents the targeted pixel,
-- arrows represent sections of the path weaving between pixels,
-- numbers are the values for the variable `dir`.

-- the order of pixels to investigate according to `dir`.
local delta = {
	{ -1,-1;  0,-1 }, -- up    ... up-left    ; up
	{  1,-1;  1, 0 }, -- right ... up-right   ; right
	{  1, 1;  0, 1 }, -- down  ... down-right ; down
	{ -1, 1; -1, 0 }, -- left  ... down-left  ; left
};

-- path-tracking function: two corners of inner pixels are considered to be connected.
local function advance_boundary_1(X,Y,dir, w,h, buf,is_inner,...)
	-- imagine you are walking along a wall, touching your right hand on it.
	local d = delta[dir+1];
	local Xt,Yt = X+d[1],Y+d[2];
	if 0<=Xt and Xt<w and 0<=Yt and Yt<h and is_inner(buf,Xt+Yt*w,...) then
		return Xt,Yt, (dir-1) % 4; -- block in front; turn left.
	end

	Xt,Yt = X+d[3],Y+d[4];
	if 0<=Xt and Xt<w and 0<=Yt and Yt<h and is_inner(buf,Xt+Yt*w,...) then
		return Xt,Yt, dir; -- block in front-right; go straight.
	end

	return X,Y, (dir+1) % 4; -- space in front-right; trun right.
end

-- path-tracking function: two corners of inner pixels are considered to be separated.
local function advance_boundary_2(X,Y,dir, w,h, buf,is_inner,...)
	-- imagine you are walking along a wall, touching your right hand on it.
	local d = delta[dir+1];
	local Xt,Yt = X+d[3],Y+d[4];
	if 0>Xt or Xt>=w or 0>Yt or Yt>=h or not is_inner(buf,Xt+Yt*w,...) then
		return X,Y, (dir+1) % 4; -- space in front-right; trun right.
	end

	X,Y,Xt,Yt = Xt,Yt,X+d[1],Y+d[2];
	if 0>Xt or Xt>=w or 0>Yt or Yt>=h or not is_inner(buf,Xt+Yt*w,...) then
		return X,Y, dir; -- space in front; go straight.
	end

	return Xt,Yt, (dir-1) % 4; -- block in front; turn left.
end

local function detect_boundary(x,y, w,h, buf,flg, advance,is_inner,...)
	-- follow the path until it closes.
	local X,Y,dir = x, y, 0;
	repeat
		X,Y,dir = advance(X,Y,dir, w,h, buf,is_inner,...);

		-- mark the path flag.
		if dir == 0 and flg[X+Y*w] == 0 then flg[X+Y*w] = 1;
		elseif dir == 2 then flg[X+Y*w] = -1 end
	until X==x and Y==y and dir==0;
end

local function figure_outer_boundary(xp,yp, w,h, buf,flg, advance,is_inner,...)
	-- flg: 0->none, 1->left (but not right) edge of a closed path, -1->either left or right.

	-- finds the outer boundary containing (xp, yp) inside, and returns its bounding box.
	local bd_l,bd_t,bd_r,bd_b=xp,yp,xp-1,yp-1;
	if 0<=xp and xp<w and 0<=yp and yp<h and is_inner(buf,xp+yp*w,...) then
		local x,y = xp,yp;
		while true do
			-- find a point on a path nearby.
			while x>0 and is_inner(buf,x-1+y*w,...) do x=x-1 end

			-- determine the path and see if it surrounds the point (xp, yp).
			local X,Y,dir,cw,ym = x, y, 0, 0,y;
			repeat
				X,Y,dir = advance(X,Y,dir, w,h, buf,is_inner,...);

				-- mark the path flag.
				if dir == 0 and flg[X+Y*w] == 0 then flg[X+Y*w] = 1;
				elseif dir == 2 then flg[X+Y*w] = -1 end

				-- surround check.
				if Y == y and dir%2==0 then
					-- increment / decrement cw, which will be non-zero
					-- at the end of the path if it surrounds (x-1, y).
					cw = cw + (X>=x and dir-1 or 1-dir);
				end

				-- update the bounding box.
				if bd_l > X then bd_l = X; ym = Y end
				bd_r=math_max(bd_r,X);
				bd_t=math_min(bd_t,Y); bd_b=math_max(bd_b,Y);
			until X==x and Y==y and dir==0;

			-- if the path doesn't surround (x-1, y),
			-- which means it surrounds (xp, yp) as desired so exit the loop.
			if cw == 0 then break end

			-- skip to the left-most point of the path.
			x,y = bd_l,ym;
		end
	end
	return bd_l,bd_t,bd_r,bd_b;
end

local function detect_inner_boundary(x,y, w,h, buf,flg, advance,is_inner,...)
	if is_inner(buf, x+y*w, ...) then return false end

	local X,Y,dir = x-1,y,2;
	while X ~= x or Y ~= y - 1 do
		X,Y,dir = advance(X,Y,dir, w,h, buf,is_inner,...);

		-- mark the path flag.
		if dir == 0 and flg[X+Y*w] == 0 then flg[X+Y*w] = 1;
		elseif dir == 2 then flg[X+Y*w] = -1 end
	end
	return true;
end
local function detect_inner_boundary_cpx(x,y, w,h, buf,flg, advance,is_inner,...)
	-- a bit complexed variant of `detect_inner_boundary` that treats
	-- overwritten pixels as the inner side (whatever current values might be).
	if is_inner(buf, x+y*w, ...) then return false end

	local X,Y,dir = x-1,y,2;
	while X ~= x or Y ~= y - 1 do -- the line Y=Y0 had been overwritten, so recognized inner.
		-- handle the case when adjacent to the area
		-- where the pixels had been overwritten beforehand.
		local Y0 = X < x and y or y-1; -- the pixels lying on Y=Y0 had been overwritten.
		if Y == Y0+1 and dir == 0 then
			-- upward (dir = 0) entering the overwritten domain.
			X,Y,dir = X-1,Y-1,3; -- turn left (dir = 3).
		elseif Y == Y0 and dir ~= 2 then
			-- going along (left; dir = 3) the overwritten pixels.
			X=X-1;
			if is_inner(buf, X+(Y+1)*w, ...) then
				-- turn downward (dir = 2), leaving overwritten domain.
				Y,dir = Y+1,2;
			end
		else X,Y,dir = advance(X,Y,dir, w,h, buf,is_inner,...) end

		-- mark the path flag.
		if dir == 0 and flg[X+Y*w] == 0 then flg[X+Y*w] = 1;
		elseif dir == 2 then flg[X+Y*w] = -1 end
	end
	return true;
end

-- transforms anchor position to image coordinate.
local function transform_anchor(xp,yp, w,h)
	-- xp=xp-obj.ox;
	-- yp=yp-obj.oy;

	-- if obj.rz ~= 0 then
	-- 	local rz=math.pi/180 * obj.rz;
	-- 	local c,s = math.cos(rz),math.sin(rz);
	-- 	xp,yp = c*xp+s*yp,-s*xp+c*yp;
	-- end

	-- xp=xp+obj.cx+w/2;
	-- yp=yp+obj.cy+h/2;

	xp=xp+obj.cx-obj.ox+w/2;
	yp=yp+obj.cy-obj.oy+h/2;
	return math.floor(xp),math.floor(yp);
end

-- used for early returns when essential process can be skipped.
local function push_alpha(alpha)
	if alpha < 1 then
		obj.setoption("dst","tmp",obj.getpixel());
		if alpha > 0 then obj.draw(0,0,0,1,alpha) end
		obj.copybuffer("obj","tmp")
	end
end

--@穴埋め
--track0:不透明度,0,100,100
--track1:着色強さ,0,100,100
--track2:前景α値,0,100,100
--track3:αしきい値,0,100,100
--check0:外枠埋め,0
--dialog:色/col,_1=0xffffff;┗輝度の保持/chk,_2=0;角で隣接扱い/chk,_3=1;PI,_0=nil;
local function fill_holes(thresh, conn_corner, alpha,col,keep_luma,col_a, front_a, outer)
	-- check / normalize arguments.
	alpha = math_min(math_max(alpha/100,0),1);
	if alpha <= 0 then return push_alpha(front_a/100) end

	thresh = 1+math.floor(253/99.9*(math_min(math_max(thresh,0),100)-0.1));
	local advance_boundary = conn_corner and advance_boundary_1 or advance_boundary_2;
	col = bit_band(0xffffff,col);
	keep_luma = keep_luma and 1 or 0;
	col_a = math_min(math_max(col_a,0),100);
	front_a = math_min(math_max(front_a/100,0),1);

	-- prepare buffer.
	local buf0,w,h = obj.getpixeldata();
	local flg0 = obj.getpixeldata("work");
	local buf,flg = ffi.cast("uint8_t*",buf0),ffi.cast("int8_t*",flg0);
	buf = buf + 3; -- alpha channel.
	ffi.fill(flg, w * h);
	-- flg: 0->none, 1->left (but not right) edge of a closed path, -1->either left or right.

	-- traverse throughout pixels.
	if outer then
		-- modified from `not outer` branch.
		for y = 0, h - 1 do local x = 0 while x < w do
			if flg[x+y*w] ~= 0 then
				repeat
					buf[4*(x+y*w)] = 255; -- fully opaque.
					x = x+1;
				until flg[x-1+y*w] < 0;
			elseif not is_opaque(buf, x+y*w, thresh) then x = x+1; -- leave the pixel unchanged.
			else detect_boundary(x,y, w,h, buf,flg, advance_boundary,is_opaque,thresh) end
		end end
	else
		for y = 0, h - 1 do local x = 0 while x < w do
			if flg[x+y*w] ~= 0 then
				-- left edge of a closed path is detected.
				-- fill the pixel until the right edge is detected.
				repeat
					buf[4*(x+y*w)] = 255-buf[4*(x+y*w)]; -- to fit with "alpha_add".
					x = x+1;
				until flg[x-1+y*w] < 0;
			elseif not is_opaque(buf, x+y*w, thresh) then
				-- outbound of the image. remove the alpha.
				buf[4*(x+y*w)] = 0;
				x = x+1;
			else
				-- unmarked closed path is detected.
				detect_boundary(x,y, w,h, buf,flg, advance_boundary,is_opaque,thresh);

				-- leave x un-incremented so `if flg[x+y*w] ~= 0 then` branch is processed.
			end
		end end
	end

	-- place the buffer back to obj.
	if front_a == 1 then
		obj.copybuffer("tmp","obj");
		obj.setoption("dst","tmp");
	elseif front_a > 0 then
		obj.setoption("dst","tmp",w,h);
		obj.draw(0,0,0,1,front_a);
	elseif alpha < 1 then
		obj.setoption("dst","tmp",w,h);
	end
	obj.putpixeldata(buf0);

	-- invert alpha when "outer bound" mode.
	if outer then obj.effect("反転","透明度反転",1) end

	-- place color if necessary.
	if col_a > 0 then obj.effect("単色化","color",col,"強さ",col_a,"輝度を保持する",keep_luma) end

	-- use the blend mode "alpha_add" to fill the area.
	if front_a > 0 or alpha < 1 then
		obj.setoption("blend","alpha_add");
		obj.draw(0,0,0,1,alpha);
		obj.copybuffer("obj","tmp");
	end
end

--@連結成分切り抜き
--track0:X,-2000,2000,0,1
--track1:Y,-2000,2000,0,1
--track2:不透明度,0,100,0
--track3:αしきい値,0,100,0
--check0:反転,0
--dialog:角で隣接扱い/chk,_1=1;PI,_0=nil;
local function extract_part(xp,yp,thresh, conn_corner, alpha,inv)
	-- check / normalize arguments.
	thresh = 1+math.floor(253/99.9*(math_min(math_max(thresh,0),100)-0.1));
	local advance_boundary = conn_corner and advance_boundary_1 or advance_boundary_2;
	alpha = math_min(math_max(alpha/100,0),1);

	-- prepare buffer.
	local buf0,w,h = obj.getpixeldata();
	local flg0 = obj.getpixeldata("work");
	local buf,flg = ffi.cast("uint8_t*",buf0),ffi.cast("int8_t*",flg0);
	buf = buf + 3; -- alpha channel.
	ffi.fill(flg, w * h);
	-- flg: 0->none, 1->left (but not right) edge of a closed path, -1->either left or right.

	-- centralize the given point (xp, yp).
	xp,yp = transform_anchor(xp,yp, w,h);

	-- identify the path surrounding (xp, yp) and its bounding box.
	local bd_l,bd_t,bd_r,bd_b=figure_outer_boundary(xp,yp,w,h,
		buf,flg,advance_boundary,is_opaque,thresh);

	-- traverse throughout pixels.
	if inv then
		-- early return when the image has no pixels to process.
		if bd_l>bd_r then return end

		for y=bd_t,bd_b do local x=bd_l; while x<=bd_r do
			if flg[x+y*w] ~= 0 then
				-- process the targeted area.
				while true do
					buf[4*(x+y*w)] = 0.5 + alpha*buf[4*(x+y*w)];
					if flg[x+y*w] < 0 then break end
					x=x+1;

					if detect_inner_boundary_cpx(x,y, w,h, buf,flg, advance_boundary,is_opaque,thresh) then
						break;
					end
				end
			end
			x=x+1;
		end end
	else
		for y=0,h-1 do local x=0; while x<w do
			if flg[x+y*w] ~= 0 then
				while flg[x+y*w] >= 0 do
					x=x+1;

					if detect_inner_boundary(x,y, w,h, buf,flg, advance_boundary,is_opaque,thresh) then
						x = x-1; -- switch to the branch for outside the targeted area.
						break;
					end
				end
			else
				-- push alpha to outbounds.
				buf[4*(x+y*w)] = 0.5 + alpha*buf[4*(x+y*w)];
			end
			x=x+1;
		end end
	end

	-- place the buffer back to obj.
	obj.putpixeldata(buf0);
end

--@透明領域塗りつぶし
--track0:X,-2000,2000,0,1
--track1:Y,-2000,2000,0,1
--track2:不透明度,0,100,100
--track3:αしきい値,0,100,100
--dialog:色/col,_1=0xffffff;前景α値(%),_2=100;角で隣接扱い/chk,_3=1;PI,_0=nil;
local function flood_fill(xp,yp,thresh, conn_corner, col,alpha,front_a)
	-- check / normalize arguments.
	alpha = math_min(math_max(alpha/100,0),1);
	if alpha <= 0 then return push_alpha(front_a/100) end

	thresh = 1+math.floor(253/99.9*(math_min(math_max(thresh,0),100)-0.1));
	local advance_boundary = conn_corner and advance_boundary_2 or advance_boundary_1;
	col = bit_band(col, 0xffffff);
	front_a = math_min(math_max(front_a/100,0),1);

	-- prepare buffer.
	local buf0,w,h = obj.getpixeldata();
	local flg0 = obj.getpixeldata("work");
	local buf,flg = ffi.cast("uint8_t*",buf0),ffi.cast("int8_t*",flg0);
	buf = buf + 3; -- alpha channel.
	ffi.fill(flg, w * h);
	-- flg: 0->none, 1->left (but not right) edge of a closed path, -1->either left or right.

	-- centralize the given point (xp, yp).
	xp,yp = transform_anchor(xp,yp, w,h);

	-- identify the path surrounding (xp, yp) and its bounding box.
	local bd_l,bd_t,bd_r,bd_b=figure_outer_boundary(xp,yp, w,h,
		buf,flg, advance_boundary,is_transparent,thresh);

	-- early return when the image has no pixels to process.
	if bd_l>bd_r then return push_alpha(front_a) end

	-- traverse throughout pixels.
	for y=bd_t,bd_b do local x=bd_l; while x<=bd_r do
		if flg[x+y*w] ~= 0 then
			-- process the targeted area.
			while true do
				buf[4*(x+y*w)] = 255-buf[4*(x+y*w)];
				if flg[x+y*w] < 0 then break end
				x=x+1;

				if detect_inner_boundary_cpx(x,y, w,h, buf,flg, advance_boundary,is_transparent,thresh) then
					x = x-1; -- switch to the branch for outside the targeted area.
					break;
				end
			end
		else
			-- erase outbounds.
			buf[4*(x+y*w)] = 0;
		end
		x=x+1;
	end end

	-- place the buffer back to obj.
	if front_a == 1 then
		obj.copybuffer("tmp","obj");
		obj.setoption("dst","tmp");
	else
		obj.setoption("dst","tmp",w,h);
		if front_a > 0 then obj.draw(0,0,0,1,front_a) end
	end
	obj.putpixeldata(buf0);

	-- shrink the buffer to fit the bounding box.
	bd_r=bd_r+1; bd_b=bd_b+1;
	xp = (bd_l+bd_r-w)/2; yp = (bd_t+bd_b-h)/2;
	obj.effect("クリッピング","中心の位置を変更",1,
		"左",bd_l, "上",bd_t, "右",w-bd_r, "下",h-bd_b);

	-- place color.
	obj.effect("単色化","color",col,"輝度を保持する",0);

	-- use the blend mode "alpha_add" to fill the area.
	obj.setoption("blend","alpha_add");
	obj.draw(xp,yp,0,1,alpha);
	obj.copybuffer("obj","tmp");
end

--@色領域塗りつぶし
--track0:不透明度,0,100,100
--track1:着色強さ,0,100,100
--track2:色範囲,0,255,8,1
--track3:αしきい値,0,100,0
--check0:着色で輝度を保持,0
--dialog:位置,_1={0,0};R範囲補正,_2=1.0;G範囲補正,_3=1.0;B範囲補正,_4=1.0;着色/col,_5=0xffffff;前景α値(%),_6=100;角で隣接扱い/chk,_7=1;PI,_0=nil;
local function flood_fill_col(xp,yp, col_diff,r_diff_coeff,g_diff_coeff,b_diff_coeff,thresh, conn_corner, col,keep_luma,col_a, alpha,front_a)
	-- check / normalize arguments.
	alpha = math_min(math_max(alpha/100,0),1);
	front_a = math_min(math_max(front_a/100,0),1);
	col_a = math_min(math_max(col_a,0),100);
	if alpha == front_a and (alpha == 0 or col_a == 0) then return push_alpha(front_a) end

	local r_M,g_M,b_M =
		math_max(math.floor(0.5 + col_diff*r_diff_coeff),0),
		math_max(math.floor(0.5 + col_diff*g_diff_coeff),0),
		math_max(math.floor(0.5 + col_diff*b_diff_coeff),0);
	thresh = 1+math.floor(253/99.9*(math_min(math_max(thresh,0),100)-0.1));
	local advance_boundary = conn_corner and advance_boundary_1 or advance_boundary_2;
	col = bit_band(col, 0xffffff);
	keep_luma = keep_luma and 1 or 0;

	-- prepare buffer.
	local buf0,w,h = obj.getpixeldata();
	local flg0 = obj.getpixeldata("work");
	local buf,flg = ffi.cast("uint8_t*",buf0),ffi.cast("int8_t*",flg0);
	ffi.fill(flg, w * h);
	-- flg: 0->none, 1->left (but not right) edge of a closed path, -1->either left or right.

	-- centralize the given point (xp, yp).
	xp,yp = transform_anchor(xp,yp, w,h);

	-- prepare the acceptable color range.
	local r_m,g_m,b_m do
		local I = math_min(math_max(xp+yp*w,0),w*h-1);
		r_m,g_m,b_m=buf[0+4*I],buf[1+4*I],buf[2+4*I];
	end
	r_m,r_M = math_max(r_m-r_M,0),math_min(r_m+r_M,255);
	g_m,g_M = math_max(g_m-g_M,0),math_min(g_m+g_M,255);
	b_m,b_M = math_max(b_m-b_M,0),math_min(b_m+b_M,255);

	-- identify the path surrounding (xp, yp) and its bounding box.
	local bd_l,bd_t,bd_r,bd_b=figure_outer_boundary(xp,yp, w,h,
		buf,flg, advance_boundary,color_similar, thresh,r_m,g_m,b_m,r_M,g_M,b_M)

	-- early return when the image has no pixels to process.
	if bd_l>bd_r then return push_alpha(front_a) end

	-- traverse throughout pixels.
	for y=bd_t,bd_b do local x=bd_l; while x<=bd_r do
		-- fill blank outside the targeted area.
		if flg[x+y*w] ~= 0 then
			while flg[x+y*w] >= 0 do
				x=x+1;

				if detect_inner_boundary(x,y, w,h, buf,flg,
					advance_boundary,color_similar,thresh,r_m,g_m,b_m,r_M,g_M,b_M) then
					x = x-1; -- switch to the branch for outside the targeted area.
					break;
				end
			end
		else
			-- erase outbounds.
			buf[3+4*(x+y*w)] = 0;
		end
		x=x+1;
	end end

	-- place the buffer back to obj.
	if front_a == 1 then
		obj.copybuffer("tmp","obj");
		obj.setoption("dst","tmp");
	else
		obj.setoption("dst","tmp",w,h);
		if front_a > 0 then obj.draw(0,0,0,1,front_a) end
	end
	obj.putpixeldata(buf0);

	-- shrink the buffer to fit the bounding box.
	bd_r=bd_r+1; bd_b=bd_b+1;
	xp = (bd_l+bd_r-w)/2; yp = (bd_t+bd_b-h)/2;
	obj.effect("クリッピング","中心の位置を変更",1,
		"左",bd_l, "上",bd_t, "右",w-bd_r, "下",h-bd_b);

	-- place color.
	if col_a > 0 and alpha > 0 then
		obj.effect("単色化","color",col,"強さ",col_a,"輝度を保持する",keep_luma);
	end

	-- first, erase the surrounded area by the blend mode "alpha_sub".
	if front_a > 0 then
		obj.setoption("blend","alpha_sub");
		obj.draw(xp,yp,0,1,front_a);
	end

	-- use the blend mode "alpha_add" to fill the area.
	if alpha > 0 then
		obj.setoption("blend","alpha_add");
		obj.draw(xp,yp,0,1,alpha);
	end
	obj.copybuffer("obj","tmp");
end

-- return the library table.
return {
	fill_holes=fill_holes,
	extract_part = extract_part,
	flood_fill = flood_fill,
	flood_fill_col = flood_fill_col,
};
