function getRotationPrecomputeL(precompute_L, rotationMatrix){

	let rotate_matrix = mat4Matrix2mathMatrix(rotationMatrix);
	let rotateSHmat_band_1 = computeSquareMatrix_3by3(rotate_matrix);
	let rotateSHmat_band_2 = computeSquareMatrix_5by5(rotate_matrix);
	let rotation_precomputeL = [];

	for(i = 0;i < 3 ;i++)
	{
		let colors = math.clone(precompute_L[i]);

		//band1

		let new_color_band1 = math.multiply(rotateSHmat_band_1,[colors[1],colors[2],colors[3]]);
		colors[1] = new_color_band1[0];
		colors[2] = new_color_band1[1];
		colors[3] = new_color_band1[2];
		
		//band2

		let new_color_band2 = math.multiply(rotateSHmat_band_2,[colors[4],colors[5],colors[6],colors[7],colors[8]]);
		colors[4] = new_color_band2[0];
		colors[5] = new_color_band2[1];
		colors[6] = new_color_band2[2];
		colors[7] = new_color_band2[3];
		colors[8] = new_color_band2[4];

		rotation_precomputeL.push([colors[0], colors[1], colors[2], 
			colors[3], colors[4], colors[5],
			colors[6], colors[7], colors[8]]);
	}

	return rotation_precomputeL;
}

function computeSquareMatrix_3by3(rotationMatrix){ // 计算方阵SA(-1) 3*3 
	
	// 1、pick ni - {ni}
	let n1 = [1, 0, 0, 0]; let n2 = [0, 0, 1, 0]; let n3 = [0, 1, 0, 0];

	// 2、{P(ni)} - A  A_inverse
	let array_n1 = SHEval(n1[0],n1[1],n1[2],3);
	let array_n2 = SHEval(n2[0],n2[1],n2[2],3);
	let array_n3 = SHEval(n3[0],n3[1],n3[2],3);

	let A = math.matrix([
						 [array_n1[1],array_n2[1],array_n3[1]]
						,[array_n1[2],array_n2[2],array_n3[2]]
						,[array_n1[3],array_n2[3],array_n3[3]]
	                    ]);
	let A_inverse = math.inv(A);

	// 3、用 R 旋转 ni - {R(ni)}
	
	let n1_rotation = math.multiply(rotationMatrix, n1);
	let n2_rotation = math.multiply(rotationMatrix, n2);
	let n3_rotation = math.multiply(rotationMatrix, n3);

	// 4、R(ni) SH投影 - S
	let array_n1_rotation = SHEval(n1_rotation[0],n1_rotation[1],n1_rotation[2],3);
	let array_n2_rotation = SHEval(n2_rotation[0],n2_rotation[1],n2_rotation[2],3);
	let array_n3_rotation = SHEval(n3_rotation[0],n3_rotation[1],n3_rotation[2],3);

    let S = math.matrix([
		[array_n1_rotation[1],array_n2_rotation[1],array_n3_rotation[1]]
	   ,[array_n1_rotation[2],array_n2_rotation[2],array_n3_rotation[2]]
	   ,[array_n1_rotation[3],array_n2_rotation[3],array_n3_rotation[3]]
	   ]);
	// 5、S*A_inverse
	return math.transpose(math.multiply(S._data,A_inverse._data));

}

function computeSquareMatrix_5by5(rotationMatrix){ // 计算方阵SA(-1) 5*5
	
	// 1、pick ni - {ni}
	let k = 1 / math.sqrt(2);
	let n1 = [1, 0, 0, 0]; let n2 = [0, 0, 1, 0]; let n3 = [k, k, 0, 0]; 
	let n4 = [k, 0, k, 0]; let n5 = [0, k, k, 0];

	// 2、{P(ni)} - A  A_inverse
	let array_n1 = SHEval(n1[0],n1[1],n1[2],3);
	let array_n2 = SHEval(n2[0],n2[1],n2[2],3);
	let array_n3 = SHEval(n3[0],n3[1],n3[2],3);
	let array_n4 = SHEval(n4[0],n4[1],n4[2],3);
	let array_n5 = SHEval(n5[0],n5[1],n5[2],3);

	let A = math.matrix([
		[array_n1[4],array_n2[4],array_n3[4],array_n4[4],array_n5[4]]
	   ,[array_n1[5],array_n2[5],array_n3[5],array_n4[5],array_n5[5]]
	   ,[array_n1[6],array_n2[6],array_n3[6],array_n4[6],array_n5[6]]
	   ,[array_n1[7],array_n2[7],array_n3[7],array_n4[7],array_n5[7]]
	   ,[array_n1[8],array_n2[8],array_n3[8],array_n4[8],array_n5[8]]
	   ]);

	let A_inverse = math.inv(A);
	// 3、用 R 旋转 ni - {R(ni)}

	let n1_rotation = math.multiply(rotationMatrix, n1);
	let n2_rotation = math.multiply(rotationMatrix, n2);
	let n3_rotation = math.multiply(rotationMatrix, n3);
    let n4_rotation = math.multiply(rotationMatrix, n4);
	let n5_rotation = math.multiply(rotationMatrix, n5);
	
	


	// 4、R(ni) SH投影 - S
	let array_n1_rotation = SHEval(n1_rotation[0],n1_rotation[1],n1_rotation[2],3);
	let array_n2_rotation = SHEval(n2_rotation[0],n2_rotation[1],n2_rotation[2],3);
	let array_n3_rotation = SHEval(n3_rotation[0],n3_rotation[1],n3_rotation[2],3);
	let array_n4_rotation = SHEval(n4_rotation[0],n4_rotation[1],n4_rotation[2],3);
	let array_n5_rotation = SHEval(n5_rotation[0],n5_rotation[1],n5_rotation[2],3);



	let S = math.matrix([
		[array_n1_rotation[4],array_n2_rotation[4],array_n3_rotation[4],array_n4_rotation[4],array_n5_rotation[4]]
	   ,[array_n1_rotation[5],array_n2_rotation[5],array_n3_rotation[5],array_n4_rotation[5],array_n5_rotation[5]]
	   ,[array_n1_rotation[6],array_n2_rotation[6],array_n3_rotation[6],array_n4_rotation[6],array_n5_rotation[6]]
	   ,[array_n1_rotation[7],array_n2_rotation[7],array_n3_rotation[7],array_n4_rotation[7],array_n5_rotation[7]]
	   ,[array_n1_rotation[8],array_n2_rotation[8],array_n3_rotation[8],array_n4_rotation[8],array_n5_rotation[8]]
	   ]);

	// 5、S*A_inverse
	return math.transpose(math.multiply(S._data,A_inverse._data));

}

function mat4Matrix2mathMatrix(rotationMatrix){

	let mathMatrix = [];
	for(let i = 0; i < 4; i++){
		let r = [];
		for(let j = 0; j < 4; j++){
			r.push(rotationMatrix[i*4+j]);
		}
		mathMatrix.push(r);
	}
	return mathMatrix

}

function getMat3ValueFromRGB(precomputeL){

    let colorMat3 = [];
    for(var i = 0; i<3; i++){
        colorMat3[i] = mat3.fromValues( precomputeL[0][i], precomputeL[1][i], precomputeL[2][i],
										precomputeL[3][i], precomputeL[4][i], precomputeL[5][i],
										precomputeL[6][i], precomputeL[7][i], precomputeL[8][i] ); 
	}
    return colorMat3;
}